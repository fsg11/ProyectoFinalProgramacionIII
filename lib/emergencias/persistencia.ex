defmodule Emergencias.Persistencia do
  @moduledoc """
  Lectura y escritura de archivos de texto plano.

  Cada registro ocupa una línea y sus campos se separan con el carácter `|`.
  Por ejemplo, un recurso se guarda así:

      R001|agua|agua|50|litros|centro_acopio_1|centro

  Los efectos secundarios (leer y escribir en disco) quedan aislados en este
  módulo; los modelos solo convierten estructuras en listas de campos.
  """

  @doc "Ruta completa de un archivo dentro de la carpeta de datos."
  def ruta(archivo) do
    directorio = Application.get_env(:emergencias, :directorio_datos, "datos")
    File.mkdir_p!(directorio)
    Path.join(directorio, archivo)
  end

  @doc """
  Lee un archivo y convierte cada línea con la función `convertir`, que recibe
  la lista de campos. Si el archivo no existe retorna una lista vacía.
  Las líneas que no se puedan convertir (la función retorna nil) se ignoran.
  """
  def leer(archivo, convertir) do
    case File.read(ruta(archivo)) do
      {:ok, contenido} ->
        contenido
        |> String.split("\n", trim: true)
        |> Enum.map(&String.trim_trailing/1)
        |> Enum.reject(&(&1 == ""))
        |> Enum.map(fn linea -> linea |> String.split("|") |> convertir.() end)
        |> Enum.reject(&is_nil/1)

      {:error, _razon} ->
        []
    end
  end

  @doc """
  Sobrescribe el archivo con todos los elementos.
  `convertir` transforma cada elemento en una lista de campos.
  """
  def guardar(archivo, elementos, convertir) do
    texto =
      elementos
      |> Enum.map(convertir)
      |> Enum.map_join("", fn campos -> unir(campos) <> "\n" end)

    File.write(ruta(archivo), texto)
  end

  @doc "Agrega una línea al final del archivo (historiales y bitácora)."
  def agregar(archivo, campos) do
    File.write(ruta(archivo), unir(campos) <> "\n", [:append])
  end

  defp unir(campos) do
    campos
    |> Enum.map(&limpiar/1)
    |> Enum.join("|")
  end

  # Evita que un texto escrito por el usuario rompa el formato del archivo.
  defp limpiar(valor) do
    valor
    |> to_string()
    |> String.replace(["|", "\n", "\r"], " ")
  end
end
