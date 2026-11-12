ExUnit.start()

defmodule Emergencias.AyudaPruebas do
  @moduledoc """
  Reinicia la aplicación con una carpeta de datos vacía.

  Cada reinicio usa una carpeta NUEVA dentro de la carpeta temporal del
  sistema, en lugar de borrar `datos_test/`. Así las pruebas funcionan aunque
  el proyecto esté en OneDrive (que bloquea el borrado de archivos mientras
  sincroniza) y nunca tocan los datos reales de `datos/`.
  """

  @raiz Path.join(System.tmp_dir!(), "emergencias_pruebas")

  def reiniciar_sistema do
    Application.stop(:emergencias)

    anterior = Application.get_env(:emergencias, :directorio_datos)

    if String.starts_with?(anterior, @raiz), do: File.rm_rf(anterior), else: File.rm_rf(@raiz)

    nueva = Path.join(@raiz, Base.url_encode64(:crypto.strong_rand_bytes(9)))
    Application.put_env(:emergencias, :directorio_datos, nueva)

    {:ok, _aplicaciones} = Application.ensure_all_started(:emergencias)
    :ok
  end
end
