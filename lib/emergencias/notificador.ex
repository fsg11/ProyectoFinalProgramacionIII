defmodule Emergencias.Notificador do
  @moduledoc "Avisa a la interfaz web que los datos cambiaron."

  @servidor Emergencias.PubSub
  @tema "cambios"

  def tema, do: @tema

  def notificar do
    if Process.whereis(@servidor) do
      Phoenix.PubSub.broadcast(@servidor, @tema, :datos_actualizados)
    end

    :ok
  end
end
