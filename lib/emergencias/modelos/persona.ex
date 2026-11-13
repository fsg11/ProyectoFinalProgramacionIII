defmodule Emergencias.Persona do
  @moduledoc """
  Persona afectada. El documento (o dato de referencia) es su identificador.
  """

  defstruct documento: "", nombre: "", edad: 0, zona: "", estado: "sin_informacion"

  @estados [
    "sin_informacion",
    "reportada",
    "localizada",
    "trasladada",
    "en_albergue",
    "reunificada"
  ]

  @transiciones %{
    "sin_informacion" => ["reportada", "localizada", "trasladada", "en_albergue"],
    "reportada" => ["localizada", "trasladada", "en_albergue", "reunificada"],
    "localizada" => ["trasladada", "en_albergue", "reunificada"],
    "trasladada" => ["localizada", "en_albergue", "reunificada"],
    "en_albergue" => ["localizada", "trasladada", "reunificada"],
    "reunificada" => []
  }

  def estados, do: @estados

  def crear(documento, nombre, edad, zona, estado) do
    cond do
      documento == "" or nombre == "" ->
        {:error, "El documento y el nombre son obligatorios"}

      estado not in @estados ->
        {:error, "Estado inválido. Use: #{Enum.join(@estados, ", ")}"}

      edad < 0 ->
        {:error, "La edad no puede ser negativa"}

      true ->
        {:ok,
         %Emergencias.Persona{
           documento: documento,
           nombre: nombre,
           edad: edad,
           zona: zona,
           estado: estado
         }}
    end
  end

  def cambiar_estado(persona, nuevo_estado) do
    permitidos = Map.get(@transiciones, persona.estado, [])

    cond do
      nuevo_estado not in @estados ->
        {:error, "Estado inválido. Use: #{Enum.join(@estados, ", ")}"}

      nuevo_estado in permitidos ->
        {:ok, %{persona | estado: nuevo_estado}}

      true ->
        {:error, "Transición inválida para #{persona.documento}: #{persona.estado} -> #{nuevo_estado}"}
    end
  end

  def a_campos(p), do: [p.documento, p.nombre, p.edad, p.zona, p.estado]

  def desde_campos([documento, nombre, edad, zona, estado]) do
    %Emergencias.Persona{
      documento: documento,
      nombre: nombre,
      edad: String.to_integer(edad),
      zona: zona,
      estado: estado
    }
  end

  def desde_campos(_campos), do: nil

  defimpl String.Chars, for: Emergencias.Persona do
    def to_string(p), do: "#{p.documento} - #{p.nombre}, #{p.edad} años - zona #{p.zona} - #{p.estado}"
  end
end
