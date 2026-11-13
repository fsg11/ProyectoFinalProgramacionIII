defmodule Emergencias.ConcurrenciaTest do
  use ExUnit.Case, async: false

  alias Emergencias.{Albergue, Albergues, Necesidades, Recurso, Recursos}

  setup do
    Emergencias.AyudaPruebas.reiniciar_sistema()
  end

  defp necesidad(cantidad) do
    {:ok, n} =
      Necesidades.registrar(%{
        tipo: "agua",
        cantidad: cantidad,
        prioridad: "critica",
        zona: "centro",
        descripcion: "prueba",
        responsable: "test",
        destino: "-"
      })

    n
  end

  test "dos solicitudes simultáneas (30 y 25) sobre 50 litros: solo una se confirma" do
    {:ok, recurso} = Recurso.crear("R001", "agua", "agua", 50, "litros", "centro_acopio_1", "centro")
    {:ok, _} = Recursos.registrar(recurso, "test")
    n1 = necesidad(30)
    n2 = necesidad(25)

    resultados =
      [{n1.id, 30}, {n2.id, 25}]
      |> Enum.map(fn {id, cantidad} -> Task.async(fn -> Necesidades.asignar(id, "agua", cantidad, "test") end) end)
      |> Enum.map(&Task.await/1)

    confirmadas = Enum.count(resultados, &match?({:ok, _, _}, &1))
    rechazadas = Enum.count(resultados, &match?({:error, _}, &1))
    {:ok, final} = Recursos.obtener("R001")

    assert confirmadas == 1
    assert rechazadas == 1
    assert final.cantidad in [20, 25]
  end

  test "100 solicitudes simultáneas de 1 unidad sobre 50 unidades: exactamente 50 se confirman" do
    {:ok, recurso} = Recurso.crear("R002", "alimentos", "alimentos", 50, "raciones", "centro_acopio_1", "centro")
    {:ok, _} = Recursos.registrar(recurso, "test")
    necesidades = Enum.map(1..100, fn _ -> necesidad(1) end)

    confirmadas =
      necesidades
      |> Enum.map(fn n -> Task.async(fn -> Necesidades.asignar(n.id, "R002", 1, "test") end) end)
      |> Enum.map(&Task.await/1)
      |> Enum.count(&match?({:ok, _, _}, &1))

    {:ok, final} = Recursos.obtener("R002")
    assert confirmadas == 50
    assert final.cantidad == 0
  end

  test "una necesidad no recibe más de lo requerido aunque lleguen asignaciones simultáneas" do
    {:ok, recurso} = Recurso.crear("R003", "agua", "agua", 100, "litros", "centro_acopio_1", "centro")
    {:ok, _} = Recursos.registrar(recurso, "test")
    n = necesidad(30)

    confirmadas =
      1..5
      |> Enum.map(fn _ -> Task.async(fn -> Necesidades.asignar(n.id, "R003", 10, "test") end) end)
      |> Enum.map(&Task.await/1)
      |> Enum.count(&match?({:ok, _, _}, &1))

    {:ok, final} = Recursos.obtener("R003")
    assert confirmadas == 3
    assert final.cantidad == 70
  end

  test "ingresos simultáneos a un albergue no superan la capacidad" do
    {:ok, albergue} = Albergue.crear("A01", "Albergue Norte", "norte", 10)
    {:ok, _} = Albergues.registrar(albergue)

    confirmados =
      1..30
      |> Enum.map(fn i -> Task.async(fn -> Albergues.ingresar("A01", "doc#{i}") end) end)
      |> Enum.map(&Task.await/1)
      |> Enum.count(&match?({:ok, _}, &1))

    assert confirmados == 10
  end

  test "ingresos simultáneos de la misma persona a varios albergues: solo uno se confirma" do
    for codigo <- ["B01", "B02", "B03", "B04"] do
      {:ok, albergue} = Albergue.crear(codigo, "Albergue #{codigo}", "norte", 10)
      {:ok, _} = Albergues.registrar(albergue)
    end

    confirmados =
      ["B01", "B02", "B03", "B04"]
      |> Enum.map(fn codigo -> Task.async(fn -> Albergues.ingresar(codigo, "1094") end) end)
      |> Enum.map(&Task.await/1)
      |> Enum.count(&match?({:ok, _}, &1))

    assert confirmados == 1
  end

  test "los datos se recuperan desde los archivos al reiniciar un GenServer" do
    {:ok, recurso} = Recurso.crear("R004", "agua", "agua", 40, "litros", "centro_acopio_1", "centro")
    {:ok, _} = Recursos.registrar(recurso, "test")

    pid = Process.whereis(Recursos)
    Process.exit(pid, :kill)
    Process.sleep(100)

    assert Process.whereis(Recursos) != pid
    assert {:ok, %{cantidad: 40}} = Recursos.obtener("R004")
  end
end
