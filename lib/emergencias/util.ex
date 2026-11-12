defmodule Emergencias.Util do
  @moduledoc """
  Funciones auxiliares de propósito general: mostrar mensajes, fechas,
  generación de identificadores, validación de números y lectura de
  comandos escritos por el usuario.
  """

  def mostrar(mensaje, :mensaje), do: IO.puts(mensaje)
  def mostrar(mensaje, :error), do: IO.puts(:standard_error, mensaje)

  @doc "Retorna la fecha y hora actual como texto: 2026-11-09 22:10:00"
  def fecha_actual do
    NaiveDateTime.local_now()
    |> NaiveDateTime.truncate(:second)
    |> NaiveDateTime.to_string()
  end

  @doc """
  Genera un identificador con prefijo y 3 dígitos.

      iex> Emergencias.Util.generar_id("N", 7)
      "N007"
  """
  def generar_id(prefijo, numero) do
    prefijo <> String.pad_leading(Integer.to_string(numero), 3, "0")
  end

  @doc """
  Convierte un texto a minúsculas, sin espacios extremos y sin tildes.
  Así "Crítica" y "critica" se consideran iguales.
  """
  def normalizar(texto) do
    texto
    |> to_string()
    |> String.trim()
    |> String.downcase()
    |> String.replace("á", "a")
    |> String.replace("é", "e")
    |> String.replace("í", "i")
    |> String.replace("ó", "o")
    |> String.replace("ú", "u")
  end

  @doc "Convierte un texto en entero mayor o igual a cero. Retorna {:ok, n} o {:error, mensaje}."
  def entero(texto, campo) do
    case Integer.parse(to_string(texto)) do
      {numero, ""} when numero >= 0 -> {:ok, numero}
      {_numero, ""} -> {:error, "El campo #{campo} no puede ser negativo"}
      _ -> {:error, "El campo #{campo} debe ser un número entero (se recibió '#{texto}')"}
    end
  end

  @doc "Igual que entero/2 pero exige un valor mayor que cero."
  def entero_positivo(texto, campo) do
    case entero(texto, campo) do
      {:ok, 0} -> {:error, "El campo #{campo} debe ser mayor que cero"}
      resultado -> resultado
    end
  end

  @doc """
  Separa una línea de comando en palabras, respetando el texto entre comillas.
  Es una función RECURSIVA que recorre la línea letra por letra.

      iex> Emergencias.Util.separar_palabras(~s(register_need agua 30 "Punto sector 3"))
      ["register_need", "agua", "30", "Punto sector 3"]
  """
  def separar_palabras(linea) do
    linea
    |> String.trim()
    |> String.graphemes()
    |> separar([], "", false)
  end

  # separar(letras_pendientes, palabras_encontradas, palabra_actual, dentro_de_comillas?)
  # Caso base: no quedan letras.
  defp separar([], palabras, "", _comillas), do: Enum.reverse(palabras)
  defp separar([], palabras, actual, _comillas), do: Enum.reverse([actual | palabras])

  # Una comilla abre o cierra un texto.
  defp separar(["\"" | resto], palabras, actual, comillas),
    do: separar(resto, palabras, actual, not comillas)

  # Un espacio fuera de comillas termina la palabra actual.
  defp separar([" " | resto], palabras, "", false),
    do: separar(resto, palabras, "", false)

  defp separar([" " | resto], palabras, actual, false),
    do: separar(resto, [actual | palabras], "", false)

  # Cualquier otra letra se agrega a la palabra actual.
  defp separar([letra | resto], palabras, actual, comillas),
    do: separar(resto, palabras, actual <> letra, comillas)

  @doc """
  Convierte argumentos de la forma clave=valor en una lista de tuplas.

      iex> Emergencias.Util.filtros(["zona=centro", "prioridad=critica"])
      [{"zona", "centro"}, {"prioridad", "critica"}]
  """
  def filtros(argumentos) do
    argumentos
    |> Enum.filter(&String.contains?(&1, "="))
    |> Enum.map(fn argumento ->
      [clave, valor] = String.split(argumento, "=", parts: 2)
      {normalizar(clave), normalizar(valor)}
    end)
  end

  @doc "Indica si una estructura cumple todos los filtros {campo, valor}."
  def cumple_filtros?(elemento, filtros) do
    datos = Map.from_struct(elemento)

    Enum.all?(filtros, fn {clave, valor} ->
      case Enum.find(datos, fn {campo, _dato} -> Atom.to_string(campo) == clave end) do
        {_campo, dato} -> normalizar(dato) == valor
        nil -> false
      end
    end)
  end

  @doc "Convierte un mapa de conteos en texto: \"pendiente: 2, atendida: 1\""
  def formatear_conteo(mapa) when map_size(mapa) == 0, do: "ninguno"

  def formatear_conteo(mapa) do
    mapa
    |> Enum.sort()
    |> Enum.map_join(", ", fn {clave, valor} -> "#{clave}: #{valor}" end)
  end

  @doc "Convierte una lista en texto, un elemento por línea."
  def lista_a_texto([], _formato), do: "  (sin resultados)"
  def lista_a_texto(lista, formato), do: Enum.map_join(lista, "\n", formato)
end
