defmodule EmergenciasWeb.SesionController do
  @moduledoc "Inicio y cierre de sesión con el comando connect."

  use EmergenciasWeb, :controller

  alias Emergencias.{Comandos, Usuarios}
  alias EmergenciasWeb.Acciones

  def nueva(conn, _parametros) do
    if sesion_activa?(conn) do
      redirect(conn, to: ~p"/panel")
    else
      render(conn, :nueva, error: nil, datos: %{})
    end
  end

  def crear(conn, parametros) do
    usuario = Acciones.param(parametros, "usuario")
    contrasena = Acciones.param(parametros, "contrasena")
    tipo = Acciones.param(parametros, "tipo")
    zona = Acciones.param(parametros, "zona")
    nombre = Acciones.param(parametros, "nombre")

    extras =
      if zona == "" and nombre == "" and tipo in ["", "ciudadano"],
        do: [],
        else: [blanco(tipo, "ciudadano"), blanco(zona, "sin_zona"), nombre]

    linea = Acciones.armar_linea(["connect", usuario, contrasena | extras])

    case Comandos.ejecutar(linea, nil) do
      {texto, %{usuario: usuario, token: token}} ->
        conn
        |> configure_session(renew: true)
        |> put_session("usuario", usuario)
        |> put_session("token", token)
        |> put_flash(:info, texto)
        |> redirect(to: ~p"/panel")

      {texto, nil} ->
        render(conn, :nueva, error: texto, datos: parametros)
    end
  end

  def eliminar(conn, _parametros) do
    with usuario when is_binary(usuario) <- get_session(conn, "usuario"),
         token when is_binary(token) <- get_session(conn, "token") do
      Comandos.ejecutar("disconnect", %{usuario: usuario, token: token})
    end

    conn
    |> clear_session()
    |> put_flash(:info, "Sesión cerrada.")
    |> redirect(to: ~p"/")
  end

  defp sesion_activa?(conn) do
    with usuario when is_binary(usuario) <- get_session(conn, "usuario"),
         token when is_binary(token) <- get_session(conn, "token"),
         {:ok, _datos} <- Usuarios.validar_sesion(usuario, token) do
      true
    else
      _ -> false
    end
  end

  defp blanco("", defecto), do: defecto
  defp blanco(valor, _defecto), do: valor
end
