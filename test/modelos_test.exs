defmodule Emergencias.ModelosTest do
  use ExUnit.Case, async: true

  alias Emergencias.{Albergue, Mascota, Necesidad, Recurso}

  defp necesidad(id, prioridad, estado \\ "pendiente") do
    %Necesidad{id: id, tipo: "agua", cantidad: 30, prioridad: prioridad, estado: estado, fecha: "2026"}
  end

  test "las contraseñas se cifran con sal y se verifican" do
    {:ok, a} = Emergencias.Usuario.crear("ana", "secreta", "Ana", "ciudadano", "centro")
    {:ok, b} = Emergencias.Usuario.crear("beto", "secreta", "Beto", "ciudadano", "centro")

    assert a.contrasena =~ ~r/^pbkdf2_sha256\$\d+\$[0-9a-f]{32}\$[0-9a-f]{64}$/
    refute a.contrasena =~ "secreta"
    assert a.contrasena != b.contrasena

    assert Emergencias.Usuario.contrasena_valida?(a, "secreta")
    refute Emergencias.Usuario.contrasena_valida?(a, "otra")
    refute Emergencias.Usuario.contrasena_valida?(%{a | contrasena: "pbkdf2_sha256$x$y$z"}, "secreta")

    antiguo = %{a | contrasena: Base.encode16(:crypto.hash(:sha256, "secreta"), case: :lower)}
    assert Emergencias.Usuario.contrasena_valida?(antiguo, "secreta")
    refute Emergencias.Usuario.contrasena_valida?(antiguo, "otra")
    assert Emergencias.Usuario.requiere_actualizacion?(antiguo)
    refute Emergencias.Usuario.requiere_actualizacion?(a)
  end

  test "las necesidades se ordenan por prioridad" do
    ordenadas =
      [necesidad("N1", "baja"), necesidad("N2", "critica"), necesidad("N3", "media")]
      |> Necesidad.ordenar_por_prioridad()

    assert Enum.map(ordenadas, & &1.id) == ["N2", "N3", "N1"]
  end

  test "transiciones de estado de una necesidad" do
    assert {:ok, %{estado: "en_atencion"}} = Necesidad.cambiar_estado(necesidad("N1", "alta"), "en_atencion")
    assert {:error, _} = Necesidad.cambiar_estado(necesidad("N1", "alta"), "atendida")
    assert {:error, _} = Necesidad.cambiar_estado(necesidad("N1", "alta", "atendida"), "cancelada")
    assert {:error, _} = Necesidad.validar_asignacion(necesidad("N1", "alta", "atendida"), 5)
    assert {:error, _} = Necesidad.validar_asignacion(necesidad("N1", "alta"), 31)
  end

  test "repartir toma de varios lotes sin superar el disponible" do
    lotes = [
      %Recurso{codigo: "R1", cantidad: 10},
      %Recurso{codigo: "R2", cantidad: 50}
    ]

    assert Recurso.total(lotes) == 60
    assert Recurso.repartir(lotes, 30) == [{"R1", 10}, {"R2", 20}]
    assert {:error, _} = Recurso.salida(%Recurso{codigo: "R1", cantidad: 10}, 11)
  end

  test "el albergue no supera su capacidad ni acepta duplicados" do
    {:ok, albergue} = Albergue.crear("A01", "Albergue Norte", "norte", 2)
    {:ok, albergue} = Albergue.ingresar(albergue, "111")
    assert {:error, _} = Albergue.ingresar(albergue, "111")
    {:ok, albergue} = Albergue.ingresar(albergue, "222")
    assert {:error, _} = Albergue.ingresar(albergue, "333")
    assert Albergue.cupos(albergue) == 0
    assert {:error, _} = Albergue.crear("A02", "X", "norte", -1)
  end

  test "similitud entre mascotas perdidas y encontradas" do
    perdida = %Mascota{id: "M1", tipo: "perdida", especie: "perro", nombre: "Luna", color: "negra", tamano: "mediana", zona: "norte"}
    encontrada = %Mascota{id: "M2", tipo: "encontrada", especie: "perro", nombre: "desconocido", color: "negro", tamano: "mediano", zona: "norte"}
    gato = %{encontrada | id: "M3", especie: "gato"}

    assert Mascota.similitud(perdida, encontrada) == 90
    assert Mascota.similitud(perdida, gato) == 0
    assert [{%{id: "M1"}, %{id: "M2"}, 90}] = Mascota.buscar_coincidencias([perdida, encontrada, gato])
  end
end
