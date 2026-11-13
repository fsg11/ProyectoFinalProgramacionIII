defmodule EmergenciasWeb.InterfazTest do
  use ExUnit.Case, async: false

  import Phoenix.ConnTest
  import Phoenix.LiveViewTest

  alias Emergencias.{Comandos, Usuarios}

  @endpoint EmergenciasWeb.Endpoint

  doctest EmergenciasWeb.Acciones

  setup do
    Emergencias.AyudaPruebas.reiniciar_sistema()
    {:ok, conn: build_conn()}
  end

  defp entrar(conn, usuario, extras \\ %{}) do
    conn = post(conn, "/sesion", Map.merge(%{"usuario" => usuario, "contrasena" => "1234"}, extras))
    assert redirected_to(conn) == "/panel"
    recycle(conn)
  end

  defp coordinadora(conn), do: entrar(conn, "laura", %{"tipo" => "coordinador", "zona" => "centro", "nombre" => "Laura Gómez"})

  test "la página de inicio muestra el formulario de acceso", %{conn: conn} do
    html = conn |> get("/") |> html_response(200)
    assert html =~ "Coordinación de emergencias"
    assert html =~ ~s(name="contrasena")
  end

  test "una contraseña incorrecta no inicia sesión", %{conn: conn} do
    Comandos.ejecutar("connect laura 1234 coordinador centro", nil)

    html = conn |> post("/sesion", %{"usuario" => "laura", "contrasena" => "mala"}) |> html_response(200)
    assert html =~ "Contraseña incorrecta"
  end

  test "las páginas internas exigen sesión", %{conn: conn} do
    assert {:error, {:redirect, %{to: "/"}}} = live(conn, "/panel")
    assert {:error, {:redirect, %{to: "/"}}} = live(conn, "/necesidades")
  end

  test "el registro web aplica la regla de arranque de roles", %{conn: conn} do
    conn = coordinadora(conn)
    {:ok, _vista, html} = live(conn, "/panel")
    assert html =~ "Laura Gómez"
    assert html =~ "Simular conflicto"

    html =
      build_conn()
      |> post("/sesion", %{"usuario" => "intruso", "contrasena" => "1234", "tipo" => "coordinador"})
      |> html_response(200)

    assert html =~ "solo crea ciudadanos"
  end

  test "un ciudadano no ve las acciones de coordinación", %{conn: conn} do
    Comandos.ejecutar("connect laura 1234 coordinador centro", nil)
    conn = entrar(conn, "pedro")

    {:ok, _vista, html} = live(conn, "/zonas")
    refute html =~ "Registrar zona"

    {:ok, _vista, html} = live(conn, "/panel")
    refute html =~ "Simular conflicto"
    refute html =~ "Usuarios y roles"

    assert {:error, {:live_redirect, %{to: "/panel"}}} = live(conn, "/usuarios")
  end

  test "flujo de zonas, recursos y necesidades desde la web", %{conn: conn} do
    conn = coordinadora(conn)

    {:ok, zonas, _html} = live(conn, "/zonas")

    html =
      zonas
      |> form("form[phx-submit=registrar]", %{
        "codigo" => "centro",
        "nombre" => "Zona Centro",
        "nivel" => "critico",
        "afectados" => "500"
      })
      |> render_submit()

    assert html =~ "Registrado"
    assert html =~ "Zona Centro"

    {:ok, recursos, _html} = live(conn, "/recursos")

    recursos
    |> form("form[phx-submit=registrar]", %{
      "codigo" => "R001",
      "nombre" => "agua",
      "cantidad" => "50",
      "unidad" => "litros",
      "ubicacion" => "centro_acopio_1"
    })
    |> render_submit()

    assert render(recursos) =~ "R001"

    {:ok, necesidades, _html} = live(conn, "/necesidades")

    html =
      necesidades
      |> form("form[phx-submit=registrar]", %{
        "tipo" => "agua",
        "cantidad" => "30",
        "prioridad" => "critica",
        "zona" => "centro",
        "descripcion" => "Punto de atención sector 3"
      })
      |> render_submit()

    assert html =~ "N001"

    html =
      necesidades
      |> form("#necesidad-N001 form[phx-submit=asignar]", %{"criterio" => "agua", "cantidad" => "30"})
      |> render_submit()

    assert html =~ "Asignación confirmada"
    assert {:ok, %{cantidad: 20}} = Emergencias.Recursos.obtener("R001")

    Comandos.ejecutar("register_need agua 25 alta centro \"Otro punto\"", %{
      usuario: "laura",
      token: token_de(conn)
    })

    html =
      necesidades
      |> form("#necesidad-N002 form[phx-submit=asignar]", %{"criterio" => "agua", "cantidad" => "25"})
      |> render_submit()

    assert html =~ "resultado-error"
  end

  test "la web se actualiza en tiempo real con cambios hechos desde la consola", %{conn: conn} do
    conn = coordinadora(conn)
    {:ok, panel, html} = live(conn, "/albergues")
    refute html =~ ~s(id="albergue-A01")

    {_r, juan} = Comandos.ejecutar("connect juan 1234", nil)
    Comandos.ejecutar("set_role juan voluntario", %{usuario: "laura", token: token_de(conn)})
    {_r, _} = Comandos.ejecutar("register_zone norte Norte alto 10", %{usuario: "laura", token: token_de(conn)})

    Comandos.ejecutar("register_shelter A01 \"Albergue Norte\" norte 10", %{
      usuario: "laura",
      token: token_de(conn)
    })

    Comandos.ejecutar("report_person 1094 \"Andrés Pérez\" norte localizada", juan)
    Comandos.ejecutar("register_entry A01 1094", juan)

    html = render(panel)
    assert html =~ ~s(id="albergue-A01")
    assert html =~ "Albergue Norte"
    assert html =~ "Andrés Pérez"
    assert html =~ "1/10"
  end

  test "cerrar sesión invalida el token en el servidor", %{conn: conn} do
    conn = coordinadora(conn)
    token = token_de(conn)

    conn = conn |> delete("/sesion")
    assert redirected_to(conn) == "/"
    assert {:error, _} = Usuarios.validar_sesion("laura", token)
  end

  defp token_de(conn) do
    conn |> get("/") |> Plug.Conn.get_session("token")
  end
end
