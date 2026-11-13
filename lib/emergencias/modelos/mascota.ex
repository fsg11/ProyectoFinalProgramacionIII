defmodule Emergencias.Mascota do
  @moduledoc """
  Reporte de mascota perdida o encontrada.

  ## Criterio de similitud (definido por el equipo)

  Si la especie es distinta el puntaje es 0. Si es la misma:

  | Atributo                        | Puntos |
  |---------------------------------|--------|
  | Misma especie                   | 30     |
  | Misma zona                      | 25     |
  | Mismo color (raíz de 4 letras)  | 20     |
  | Mismo tamaño (raíz de 4 letras) | 15     |
  | Mismo nombre (si ambos se conocen) | 10  |
  | Palabras en común en características | 5 c/u (máx. 10) |

  El puntaje máximo se limita a 100. Desde 60 puntos se considera
  "posible coincidencia". Se compara la raíz de 4 letras para que
  "negra" y "negro" o "mediana" y "mediano" se consideren iguales.
  """

  alias Emergencias.Util

  defstruct id: "",
            tipo: "perdida",
            especie: "",
            nombre: "desconocido",
            caracteristicas: "",
            color: "",
            tamano: "",
            zona: "",
            contacto: "",
            estado: "activa",
            coincidencia: "-"

  @umbral 60

  def umbral, do: @umbral

  def crear(datos) do
    cond do
      datos.tipo not in ["perdida", "encontrada"] ->
        {:error, "Tipo de reporte inválido. Use: lost (perdida) o found (encontrada)"}

      datos.especie == "" ->
        {:error, "La especie es obligatoria"}

      true ->
        {:ok, struct(Emergencias.Mascota, Map.merge(datos, %{estado: "activa", coincidencia: "-"}))}
    end
  end

  @doc "Puntaje de 0 a 100 que indica qué tan parecidos son dos reportes."
  def similitud(a, b) do
    if a.especie != b.especie do
      0
    else
      puntaje =
        30 +
          puntos(a.zona == b.zona, 25) +
          puntos(raiz(a.color) == raiz(b.color), 20) +
          puntos(raiz(a.tamano) == raiz(b.tamano), 15) +
          puntos_nombre(a.nombre, b.nombre) +
          puntos_caracteristicas(a.caracteristicas, b.caracteristicas)

      min(puntaje, 100)
    end
  end

  defp puntos(true, valor), do: valor
  defp puntos(false, _valor), do: 0

  defp raiz(texto), do: texto |> Util.normalizar() |> String.slice(0, 4)

  defp puntos_nombre(nombre1, nombre2) do
    desconocidos = ["desconocido", "-", ""]
    n1 = Util.normalizar(nombre1)
    n2 = Util.normalizar(nombre2)

    if n1 in desconocidos or n2 in desconocidos or n1 != n2, do: 0, else: 10
  end

  # Usa MapSet para encontrar las palabras en común.
  defp puntos_caracteristicas(texto1, texto2) do
    comunes = MapSet.intersection(palabras(texto1), palabras(texto2))
    min(MapSet.size(comunes) * 5, 10)
  end

  defp palabras(texto) do
    texto
    |> Util.normalizar()
    |> String.split([" ", ",", ";"], trim: true)
    |> Enum.filter(fn palabra -> String.length(palabra) > 3 end)
    |> MapSet.new()
  end

  @doc """
  Compara cada reporte de mascota perdida con cada reporte de mascota
  encontrada (que no estén resueltos) y retorna las parejas con puntaje
  mayor o igual al umbral, de mayor a menor puntaje.
  """
  def buscar_coincidencias(reportes) do
    abiertos = Enum.filter(reportes, fn r -> r.estado != "resuelta" end)
    perdidas = Enum.filter(abiertos, fn r -> r.tipo == "perdida" end)
    encontradas = Enum.filter(abiertos, fn r -> r.tipo == "encontrada" end)

    perdidas
    |> Enum.flat_map(fn p -> Enum.map(encontradas, fn e -> {p, e, similitud(p, e)} end) end)
    |> Enum.filter(fn {_p, _e, puntaje} -> puntaje >= @umbral end)
    |> Enum.sort_by(fn {_p, _e, puntaje} -> puntaje end, :desc)
  end

  def a_campos(m) do
    [
      m.id,
      m.tipo,
      m.especie,
      m.nombre,
      m.caracteristicas,
      m.color,
      m.tamano,
      m.zona,
      m.contacto,
      m.estado,
      m.coincidencia
    ]
  end

  def desde_campos([
        id,
        tipo,
        especie,
        nombre,
        caracteristicas,
        color,
        tamano,
        zona,
        contacto,
        estado,
        coincidencia
      ]) do
    %Emergencias.Mascota{
      id: id,
      tipo: tipo,
      especie: especie,
      nombre: nombre,
      caracteristicas: caracteristicas,
      color: color,
      tamano: tamano,
      zona: zona,
      contacto: contacto,
      estado: estado,
      coincidencia: coincidencia
    }
  end

  def desde_campos(_campos), do: nil

  defimpl String.Chars, for: Emergencias.Mascota do
    def to_string(m) do
      "#{m.id} (#{m.tipo}) #{m.especie} '#{m.nombre}' #{m.color}, #{m.tamano} - zona #{m.zona} - " <>
        "contacto #{m.contacto} - #{m.estado}" <>
        if(m.coincidencia != "-", do: " con #{m.coincidencia}", else: "")
    end
  end
end
