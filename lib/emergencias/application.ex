defmodule Emergencias.Application do
  @moduledoc """
  Punto de arranque de la aplicación. Construye el árbol de supervisión:

      Emergencias.Supervisor (one_for_one)
      ├── Emergencias.Bitacora            (proceso spawn/receive)
      ├── Emergencias.SupervisorDominio   (one_for_one)
      │   ├── Usuarios      (GenServer)
      │   ├── Zonas         (GenServer)
      │   ├── Recursos      (GenServer)
      │   ├── Necesidades   (GenServer)
      │   ├── Personas      (GenServer)
      │   ├── Mensajes      (GenServer)
      │   ├── Mascotas      (GenServer)
      │   └── Albergues     (GenServer)
      ├── Emergencias.ServidorRemoto      (proceso spawn/receive para clientes en otros nodos)
      ├── Phoenix.PubSub                  (avisos de cambios para la interfaz web)
      └── EmergenciasWeb.Endpoint         (interfaz web; solo escucha con `mix phx.server`)
  """

  use Application

  @impl true
  def start(_tipo, _argumentos) do
    hijos = [
      Emergencias.Bitacora,
      Emergencias.SupervisorDominio,
      Emergencias.ServidorRemoto,
      {Phoenix.PubSub, name: Emergencias.PubSub},
      EmergenciasWeb.Endpoint
    ]

    Supervisor.start_link(hijos, strategy: :one_for_one, name: Emergencias.Supervisor)
  end
end
