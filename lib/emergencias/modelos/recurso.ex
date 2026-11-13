defmodule Emergencias.Recurso do
  @moduledoc """
  Recurso disponible en un centro de acopio, albergue o punto de atención.
  Todas las funciones son puras: reciben un recurso y retornan uno nuevo.
  """

  alias Emergencias.Util

  defstruct codigo: "",
            nombre: "",
            categoria: "",
            cantidad: 0,
            unidad: "",
            ubicacion: "",
            zona: ""

  def crear(codigo, nombre, categoria, cantidad, unidad, ubicacion, zona) do
    cond do
      codigo == "" or nombre == "" ->
        {:error, "El código y el nombre del recurso son obligatorios"}

      not is_integer(cantidad) or cantidad < 0 ->
        {:error, "La cantidad del recurso no puede ser negativa"}

      true ->
        {:ok,
         %Emergencias.Recurso{
           codigo: codigo,
           nombre: nombre,
           categoria: categoria,
           cantidad: cantidad,
           unidad: unidad,
           ubicacion: ubicacion,
           zona: zona
         }}
    end
  end

  def entrada(recurso, cantidad) when is_integer(cantidad) and cantidad > 0 do
    {:ok, %{recurso | cantidad: recurso.cantidad + cantidad}}
  end

  def entrada(_recurso, _cantidad), do: {:error, "La cantidad de entrada debe ser mayor que cero"}

  def salida(recurso, cantidad) when is_integer(cantidad) and cantidad > 0 do
    if cantidad <= recurso.cantidad do
      {:ok, %{recurso | cantidad: recurso.cantidad - cantidad}}
    else
      {:error,
       "Inventario insuficiente en #{recurso.codigo}: se solicitan #{cantidad} y hay #{recurso.cantidad}"}
    end
  end

  def salida(_recurso, _cantidad), do: {:error, "La cantidad de salida debe ser mayor que cero"}

  @doc "Un recurso coincide si el criterio es su código, su nombre o su categoría."
  def coincide?(recurso, criterio) do
    criterio = Util.normalizar(criterio)

    Util.normalizar(recurso.codigo) == criterio or
      recurso.nombre == criterio or
      recurso.categoria == criterio
  end

  @doc "Primero los lotes de la misma zona y, entre ellos, los que tienen más unidades."
  def ordenar_para_consumo(lotes, zona) do
    Enum.sort_by(lotes, fn r -> {r.zona != zona, -r.cantidad} end)
  end

  @doc "(Recursiva) Suma las cantidades de una lista de recursos."
  def total([]), do: 0
  def total([recurso | resto]), do: recurso.cantidad + total(resto)

  @doc """
  (Recursiva) Decide cuánto tomar de cada lote para completar `pendiente`.
  Retorna una lista de tuplas {codigo, cantidad_tomada}.

      lotes de 10 y 50, pendiente 30  ->  [{"R1", 10}, {"R2", 20}]
  """
  def repartir(_lotes, 0), do: []
  def repartir([], _pendiente), do: []

  def repartir([lote | resto], pendiente) do
    tomar = min(lote.cantidad, pendiente)

    if tomar > 0 do
      [{lote.codigo, tomar} | repartir(resto, pendiente - tomar)]
    else
      repartir(resto, pendiente)
    end
  end

  def a_campos(r), do: [r.codigo, r.nombre, r.categoria, r.cantidad, r.unidad, r.ubicacion, r.zona]

  def desde_campos([codigo, nombre, categoria, cantidad, unidad, ubicacion, zona]) do
    %Emergencias.Recurso{
      codigo: codigo,
      nombre: nombre,
      categoria: categoria,
      cantidad: String.to_integer(cantidad),
      unidad: unidad,
      ubicacion: ubicacion,
      zona: zona
    }
  end

  def desde_campos(_campos), do: nil

  defimpl String.Chars, for: Emergencias.Recurso do
    def to_string(r) do
      "#{r.codigo} - #{r.nombre} (#{r.categoria}): #{r.cantidad} #{r.unidad} en #{r.ubicacion} [zona #{r.zona}]"
    end
  end
end
