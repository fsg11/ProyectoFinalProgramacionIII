defmodule Emergencias.Albergue do
  @moduledoc """
  Albergue temporal. Las personas alojadas se guardan en un MapSet de
  documentos: así una misma persona no puede ingresar dos veces y la
  ocupación es simplemente el tamaño del conjunto.
  """

  defstruct codigo: "", nombre: "", zona: "", capacidad: 0, ocupantes: MapSet.new()

  def crear(codigo, nombre, zona, capacidad) do
    cond do
      codigo == "" or nombre == "" ->
        {:error, "El código y el nombre del albergue son obligatorios"}

      not is_integer(capacidad) or capacidad <= 0 ->
        {:error, "La capacidad máxima debe ser mayor que cero"}

      true ->
        {:ok,
         %Emergencias.Albergue{
           codigo: codigo,
           nombre: nombre,
           zona: zona,
           capacidad: capacidad,
           ocupantes: MapSet.new()
         }}
    end
  end

  def ocupacion(albergue), do: MapSet.size(albergue.ocupantes)

  def cupos(albergue), do: albergue.capacidad - ocupacion(albergue)

  def porcentaje(albergue), do: ocupacion(albergue) * 100 / albergue.capacidad

  def ingresar(albergue, documento) do
    cond do
      MapSet.member?(albergue.ocupantes, documento) ->
        {:error, "La persona #{documento} ya está registrada en #{albergue.codigo}"}

      cupos(albergue) <= 0 ->
        {:error, "El albergue #{albergue.codigo} está lleno (capacidad #{albergue.capacidad})"}

      true ->
        {:ok, %{albergue | ocupantes: MapSet.put(albergue.ocupantes, documento)}}
    end
  end

  def salir(albergue, documento) do
    if MapSet.member?(albergue.ocupantes, documento) do
      {:ok, %{albergue | ocupantes: MapSet.delete(albergue.ocupantes, documento)}}
    else
      {:error, "La persona #{documento} no está registrada en #{albergue.codigo}"}
    end
  end

  def a_campos(a) do
    [a.codigo, a.nombre, a.zona, a.capacidad, Enum.join(Enum.sort(a.ocupantes), ",")]
  end

  def desde_campos([codigo, nombre, zona, capacidad, ocupantes]) do
    %Emergencias.Albergue{
      codigo: codigo,
      nombre: nombre,
      zona: zona,
      capacidad: String.to_integer(capacidad),
      ocupantes: ocupantes |> String.split(",", trim: true) |> MapSet.new()
    }
  end

  def desde_campos(_campos), do: nil

  defimpl String.Chars, for: Emergencias.Albergue do
    def to_string(a) do
      porcentaje = :erlang.float_to_binary(Emergencias.Albergue.porcentaje(a), decimals: 1)

      "#{a.codigo} - #{a.nombre} (zona #{a.zona}): #{Emergencias.Albergue.ocupacion(a)}/#{a.capacidad} " <>
        "ocupados (#{porcentaje}%), #{Emergencias.Albergue.cupos(a)} cupos disponibles"
    end
  end
end
