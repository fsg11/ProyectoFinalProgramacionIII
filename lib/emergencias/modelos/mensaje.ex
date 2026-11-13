defmodule Emergencias.Mensaje do
  @moduledoc "Mensaje dirigido a una persona afectada o a una familia."

  alias Emergencias.Util

  defstruct id: "", fecha: "", remitente: "", destinatario: "", contenido: "", estado: "pendiente"

  def crear(id, remitente, destinatario, contenido) do
    if String.trim(contenido) == "" or destinatario == "" do
      {:error, "El destinatario y el contenido del mensaje son obligatorios"}
    else
      {:ok,
       %Emergencias.Mensaje{
         id: id,
         fecha: Util.fecha_actual(),
         remitente: remitente,
         destinatario: destinatario,
         contenido: contenido,
         estado: "pendiente"
       }}
    end
  end

  def marcar(mensaje, nuevo_estado) do
    cond do
      nuevo_estado not in ["pendiente", "entregado"] ->
        {:error, "Estado inválido. Use: pendiente o entregado"}

      mensaje.estado == nuevo_estado ->
        {:error, "El mensaje #{mensaje.id} ya está #{nuevo_estado}"}

      true ->
        {:ok, %{mensaje | estado: nuevo_estado}}
    end
  end

  def a_campos(m), do: [m.id, m.fecha, m.remitente, m.destinatario, m.contenido, m.estado]

  def desde_campos([id, fecha, remitente, destinatario, contenido, estado]) do
    %Emergencias.Mensaje{
      id: id,
      fecha: fecha,
      remitente: remitente,
      destinatario: destinatario,
      contenido: contenido,
      estado: estado
    }
  end

  def desde_campos(_campos), do: nil

  defimpl String.Chars, for: Emergencias.Mensaje do
    def to_string(m),
      do: "#{m.id} [#{m.fecha}] de #{m.remitente} para #{m.destinatario}: \"#{m.contenido}\" (#{m.estado})"
  end
end
