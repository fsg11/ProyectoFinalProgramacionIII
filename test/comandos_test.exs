defmodule Emergencias.ComandosTest do
  use ExUnit.Case, async: false

  alias Emergencias.Comandos

  setup do
    Emergencias.AyudaPruebas.reiniciar_sistema()
  end

  defp ejecutar(lineas, sesion \\ nil) do
    Enum.reduce(lineas, {"", sesion}, fn linea, {_respuesta, sesion} ->
      Comandos.ejecutar(linea, sesion)
    end)
  end

  test "conexión: registro automático, validación de contraseña y permisos" do
    {respuesta, sesion} = Comandos.ejecutar("connect laura 1234 coordinador centro", nil)
    assert respuesta =~ "registrado"
    assert sesion.usuario == "laura"

    {_respuesta, nil} = Comandos.ejecutar("disconnect", sesion)
    {respuesta, nil} = Comandos.ejecutar("connect laura clave_mala", nil)
    assert respuesta =~ "Contraseña incorrecta"

    {_respuesta, ciudadano} = Comandos.ejecutar("connect pedro 1234 ciudadano centro", nil)
    {respuesta, _} = Comandos.ejecutar("register_zone norte Norte alto 10", ciudadano)
    assert respuesta =~ "Permiso denegado"
  end

  test "flujo de ejemplo del enunciado" do
    {_r, laura} =
      ejecutar([
        "connect laura 1234 coordinador centro",
        "register_zone centro \"Zona Centro\" critico 500",
        "register_zone sector3 \"Sector 3\" alto 120 centro",
        "register_zone zona_norte \"Zona Norte\" medio 200",
        "register_need agua 30 critica sector3 \"Punto de atención sector 3\"",
        "register_need agua 25 alta centro \"Otro punto\"",
        "register_resource R001 agua 50 litros centro_acopio_1 agua centro"
      ])

    {respuesta, _} = Comandos.ejecutar("assign_resource N001 agua 30", laura)
    assert respuesta =~ "Asignación confirmada"

    {respuesta, _} = Comandos.ejecutar("assign_resource N002 agua 25", laura)
    assert respuesta =~ "rechazada"

    {_r, _} =
      ejecutar(
        [
          "register_shelter A01 \"Albergue Norte\" zona_norte 150",
          "report_person 1094 \"Andrés Pérez\" zona_norte localizada 34",
          "register_entry A01 1094",
          "send_family_message 1094 \"Estoy bien, estoy en el albergue norte\"",
          "report_pet lost perro \"Luna\" negra mediana zona_norte 3001234567",
          "report_pet found perro desconocido negra mediana zona_norte 3007654321"
        ],
        laura
      )

    {respuesta, _} = Comandos.ejecutar("find_person 1094", laura)
    assert respuesta =~ "en_albergue"

    {respuesta, _} = Comandos.ejecutar("match_pets", laura)
    assert respuesta =~ "M001"

    {respuesta, _} = Comandos.ejecutar("confirm_match M001 M002", laura)
    assert respuesta =~ "confirmada"
    {respuesta, _} = Comandos.ejecutar("confirm_match M001 M002", laura)
    assert respuesta =~ "dos veces"

    {respuesta, _} = Comandos.ejecutar("zone_status centro", laura)
    assert respuesta =~ "620"

    {respuesta, _} = Comandos.ejecutar("summary", laura)
    assert respuesta =~ "RESUMEN GLOBAL"
    assert respuesta =~ "agua (litros): 20"
  end

  test "el registro automático no permite autoasignarse roles privilegiados" do
    {_r, laura} = Comandos.ejecutar("connect laura 1234 coordinador centro", nil)

    for tipo <- ["voluntario", "coordinador", "administrador"] do
      {respuesta, sesion} = Comandos.ejecutar("connect intruso 1234 #{tipo}", nil)
      assert respuesta =~ "solo crea ciudadanos"
      assert sesion == nil
    end

    {respuesta, pepe} = Comandos.ejecutar("connect pepe 1234", nil)
    assert respuesta =~ "ciudadano"
    {respuesta, _} = Comandos.ejecutar("movements", pepe)
    assert respuesta =~ "Permiso denegado"

    {respuesta, _} = Comandos.ejecutar("set_role pepe voluntario", laura)
    assert respuesta =~ "Rol actualizado"
    {respuesta, _} = Comandos.ejecutar("movements", pepe)
    assert respuesta =~ "Historial de movimientos"

    {respuesta, _} = Comandos.ejecutar("set_role pepe administrador", laura)
    assert respuesta =~ "no puede otorgar"
    {respuesta, _} = Comandos.ejecutar("set_role laura ciudadano", laura)
    assert respuesta =~ "propio rol"
    {respuesta, _} = Comandos.ejecutar("set_role laura ciudadano", pepe)
    assert respuesta =~ "Permiso denegado"
    {respuesta, _} = Comandos.ejecutar("set_role nadie voluntario", laura)
    assert respuesta =~ "No existe el usuario"
  end

  test "disconnect con un token falso no cierra la sesión real" do
    {_r, laura} = Comandos.ejecutar("connect laura 1234 coordinador centro", nil)

    {respuesta, nil} = Comandos.ejecutar("disconnect", %{usuario: "laura", token: "FALSO"})
    assert respuesta =~ "Sesión no válida"

    {respuesta, ^laura} = Comandos.ejecutar("list_zones", laura)
    refute respuesta =~ "Sesión no válida"

    {respuesta, nil} = Comandos.ejecutar("disconnect", laura)
    assert respuesta =~ "Sesión cerrada"
  end

  test "una persona no puede estar alojada en dos albergues" do
    {_r, laura} =
      ejecutar([
        "connect laura 1234 coordinador norte",
        "register_zone norte Norte alto 10",
        "register_shelter A01 \"Albergue Norte\" norte 10",
        "register_shelter A02 \"Albergue Sur\" norte 10",
        "report_person 1094 \"Andrés Pérez\" norte localizada 34"
      ])

    {respuesta, _} = Comandos.ejecutar("register_entry A01 1094", laura)
    assert respuesta =~ "Ingreso registrado"

    {respuesta, _} = Comandos.ejecutar("register_entry A02 1094", laura)
    assert respuesta =~ "ya está alojada en el albergue A01"
    assert {:ok, a02} = Emergencias.Albergues.obtener("A02")
    assert Emergencias.Albergue.ocupacion(a02) == 0

    {_r, _} = Comandos.ejecutar("register_exit A01 1094", laura)
    {respuesta, _} = Comandos.ejecutar("register_entry A02 1094", laura)
    assert respuesta =~ "Ingreso registrado"
  end

  test "no se ocupa un cupo con personas inexistentes o reunificadas" do
    {_r, laura} =
      ejecutar([
        "connect laura 1234 coordinador norte",
        "register_zone norte Norte alto 10",
        "register_shelter A01 \"Albergue Norte\" norte 10",
        "report_person 5555 \"Ana Ruiz\" norte reunificada",
        "report_person 7777 \"Luis Gil\" norte en_albergue"
      ])

    {respuesta, _} = Comandos.ejecutar("register_entry A01 9999", laura)
    assert respuesta =~ "No existe una persona"

    {respuesta, _} = Comandos.ejecutar("register_entry A01 5555", laura)
    assert respuesta =~ "No se puede ingresar"

    {:ok, a01} = Emergencias.Albergues.obtener("A01")
    assert Emergencias.Albergue.ocupacion(a01) == 0

    {respuesta, _} = Comandos.ejecutar("register_entry A01 7777", laura)
    assert respuesta =~ "Ingreso registrado"
  end

  test "transfer_resource solo acepta destinos existentes" do
    {_r, laura} =
      ejecutar([
        "connect laura 1234 coordinador norte",
        "register_zone norte Norte alto 10",
        "register_resource R001 agua 50 litros centro_acopio_1",
        "register_resource R002 mantas 10 unidades centro_acopio_2"
      ])

    {respuesta, _} = Comandos.ejecutar("transfer_resource R001 centro_acopio_1 bodega_fantasma 10", laura)
    assert respuesta =~ "no existe"
    assert {:ok, %{cantidad: 50}} = Emergencias.Recursos.obtener("R001")

    {respuesta, _} = Comandos.ejecutar("transfer_resource R001 centro_acopio_1 centro_acopio_2 10", laura)
    assert respuesta =~ "Transferencia realizada"

    {_r, _} = Comandos.ejecutar("register_shelter A01 \"Albergue Norte\" norte 10", laura)
    {respuesta, _} = Comandos.ejecutar("transfer_resource R001 centro_acopio_1 A01 5", laura)
    assert respuesta =~ "Transferencia realizada"
    assert {:ok, %{cantidad: 35}} = Emergencias.Recursos.obtener("R001")
  end

  test "simulate_conflict no deja datos de la simulación" do
    {_r, laura} =
      ejecutar([
        "connect laura 1234 coordinador centro",
        "register_zone centro Centro alto 10",
        "register_need agua 10 alta centro \"necesidad real\""
      ])

    {respuesta, _} = Comandos.ejecutar("simulate_conflict", laura)
    assert respuesta =~ "CONFIRMADA"
    assert respuesta =~ "RECHAZADA"

    assert Emergencias.Recursos.listar() == []
    assert Emergencias.Recursos.movimientos() == []
    assert [%{id: "N001"}] = Emergencias.Necesidades.listar()

    {_r, _} = Comandos.ejecutar("register_need agua 5 alta centro \"otra\"", laura)
    Process.exit(Process.whereis(Emergencias.Necesidades), :kill)
    Process.sleep(100)
    {_r, _} = Comandos.ejecutar("register_need agua 7 alta centro \"tercera\"", laura)
    {_r, _} = Comandos.ejecutar("register_need agua 9 alta centro \"cuarta\"", laura)
    assert length(Emergencias.Necesidades.listar()) == 4
  end

  test "confirm_match valida especie y similitud; las posibles coincidencias se recalculan" do
    {_r, laura} =
      ejecutar([
        "connect laura 1234 coordinador norte",
        "register_zone norte Norte alto 10",
        "register_zone sur Sur bajo 10",
        "report_pet lost perro \"Luna\" negra mediana norte 3001",
        "report_pet found gato desconocido negra mediana norte 3002",
        "report_pet found perro desconocido blanco grande sur 3003",
        "report_pet found perro desconocido negro mediano norte 3004",
        "report_pet found perro desconocido negra mediana norte 3005"
      ])

    {respuesta, _} = Comandos.ejecutar("confirm_match M001 M002", laura)
    assert respuesta =~ "especie no coincide"
    {respuesta, _} = Comandos.ejecutar("confirm_match M001 M003", laura)
    assert respuesta =~ "menor al umbral"

    {respuesta, _} = Comandos.ejecutar("match_pets", laura)
    assert respuesta =~ "M004"
    assert respuesta =~ "M005"
    assert estado_mascota("M004") == "posible_coincidencia"

    {respuesta, _} = Comandos.ejecutar("confirm_match M001 M005", laura)
    assert respuesta =~ "confirmada"

    assert estado_mascota("M004") == "activa"
    assert estado_mascota("M001") == "resuelta"
  end

  test "register_exit actualiza el estado de la persona solo cuando corresponde" do
    {_r, laura} =
      ejecutar([
        "connect laura 1234 coordinador norte",
        "register_zone norte Norte alto 10",
        "register_shelter A01 \"Albergue Norte\" norte 10",
        "report_person 1094 \"Andrés Pérez\" norte localizada",
        "report_person 2020 \"Bea Ríos\" norte localizada",
        "register_entry A01 1094",
        "register_entry A01 2020"
      ])

    {respuesta, _} = Comandos.ejecutar("register_exit A01 1094", laura)
    assert respuesta =~ "Estado de Andrés Pérez: localizada"
    assert {:ok, %{estado: "localizada"}} = Emergencias.Personas.obtener("1094")

    {_r, _} = Comandos.ejecutar("update_person 2020 reunificada", laura)
    {respuesta, _} = Comandos.ejecutar("register_exit A01 2020", laura)
    assert respuesta =~ "sin cambios: reunificada"
    assert {:ok, %{estado: "reunificada"}} = Emergencias.Personas.obtener("2020")

    {:ok, a01} = Emergencias.Albergues.obtener("A01")
    assert Emergencias.Albergue.ocupacion(a01) == 0

    {respuesta, _} = Comandos.ejecutar("register_exit A01 1094", laura)
    assert respuesta =~ "Error"
  end

  defp estado_mascota(id) do
    Emergencias.Mascotas.listar() |> Enum.find(&(&1.id == id)) |> Map.fetch!(:estado)
  end

  test "una contraseña con el formato antiguo se migra al iniciar sesión" do
    directorio = Application.get_env(:emergencias, :directorio_datos)
    archivo = Path.join(directorio, "usuarios.txt")
    hash_antiguo = Base.encode16(:crypto.hash(:sha256, "1234"), case: :lower)

    Application.stop(:emergencias)
    File.mkdir_p!(directorio)
    File.write!(archivo, "laura|#{hash_antiguo}|Laura|coordinador|centro\n")
    {:ok, _} = Application.ensure_all_started(:emergencias)

    {respuesta, nil} = Comandos.ejecutar("connect laura mala", nil)
    assert respuesta =~ "Contraseña incorrecta"
    assert File.read!(archivo) =~ hash_antiguo

    {_respuesta, sesion} = Comandos.ejecutar("connect laura 1234", nil)
    assert sesion.usuario == "laura"

    contenido = File.read!(archivo)
    refute contenido =~ hash_antiguo
    assert contenido =~ "laura|pbkdf2_sha256$"

    {_r, nil} = Comandos.ejecutar("disconnect", sesion)
    {_r, sesion} = Comandos.ejecutar("connect laura 1234", nil)
    assert sesion.usuario == "laura"
  end

  test "validaciones de entrada" do
    {_r, laura} = Comandos.ejecutar("connect laura 1234 coordinador centro", nil)

    {respuesta, _} = Comandos.ejecutar("register_need agua -5 critica centro \"x\"", laura)
    assert respuesta =~ "Error"

    {respuesta, _} = Comandos.ejecutar("register_need agua 5 critica zona_inexistente \"x\"", laura)
    assert respuesta =~ "no está registrada"

    {respuesta, _} = Comandos.ejecutar("register_resource R001 agua", laura)
    assert respuesta =~ "Uso:"

    {respuesta, _} = Comandos.ejecutar("comando_raro", laura)
    assert respuesta =~ "desconocido"
  end
end
