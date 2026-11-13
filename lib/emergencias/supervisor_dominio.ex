defmodule Emergencias.SupervisorDominio do
  @moduledoc """
  Supervisor de los GenServers del dominio.

  Estrategia :one_for_one: si un GenServer falla, solo ese se reinicia.
  Al reiniciarse vuelve a leer su información desde los archivos de texto,
  por lo que no se pierden los datos ya guardados.
  """

  use Supervisor

  def start_link(_argumentos) do
    Supervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @impl true
  def init(:ok) do
    hijos = [
      Emergencias.Usuarios,
      Emergencias.Zonas,
      Emergencias.Recursos,
      # Necesidades usa a Recursos, por eso se inicia después.
      Emergencias.Necesidades,
      Emergencias.Personas,
      Emergencias.Mensajes,
      Emergencias.Mascotas,
      Emergencias.Albergues
    ]

    Supervisor.init(hijos, strategy: :one_for_one)
  end
end
