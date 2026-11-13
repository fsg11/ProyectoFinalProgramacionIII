defmodule Emergencias.Usuarios do
  @moduledoc """
  GenServer que administra los usuarios registrados y las sesiones activas.

  Estado:

      %{
        usuarios: %{"laura" => %Usuario{}, ...},     # mapa usuario -> estructura
        conectados: %{"laura" => "A1B2C3...", ...}   # mapa usuario -> token de sesión
      }

  El token evita que un cliente se haga pasar por otro usuario: cada comando
  debe enviar el usuario y el token que recibió al conectarse.
  """

  use GenServer
  alias Emergencias.{Persistencia, Usuario}

  @archivo "usuarios.txt"

  def start_link(_argumentos), do: GenServer.start_link(__MODULE__, :ok, name: __MODULE__)

  def conectar(usuario, contrasena, tipo, zona, nombre),
    do: GenServer.call(__MODULE__, {:conectar, usuario, contrasena, tipo, zona, nombre})

  @doc "Cierra la sesión solo si el token corresponde a la sesión activa del usuario."
  def desconectar(usuario, token), do: GenServer.call(__MODULE__, {:desconectar, usuario, token})

  @doc """
  `quien` cambia el tipo de `usuario`. No se puede otorgar un rol superior al
  propio, ni modificar a alguien de rol superior, ni cambiar el rol propio.
  """
  def cambiar_rol(quien, usuario, tipo),
    do: GenServer.call(__MODULE__, {:cambiar_rol, quien, usuario, tipo})

  def validar_sesion(usuario, token),
    do: GenServer.call(__MODULE__, {:validar_sesion, usuario, token})

  def listar, do: GenServer.call(__MODULE__, :listar)

  @impl true
  def init(:ok) do
    usuarios =
      @archivo
      |> Persistencia.leer(&Usuario.desde_campos/1)
      |> Map.new(fn u -> {u.usuario, u} end)

    {:ok, %{usuarios: usuarios, conectados: %{}}}
  end

  @impl true
  def handle_call({:conectar, usuario, contrasena, tipo, zona, nombre}, _from, estado) do
    case Map.fetch(estado.usuarios, usuario) do
      {:ok, existente} ->
        if Usuario.contrasena_valida?(existente, contrasena) do
          estado = migrar_contrasena(estado, existente, contrasena)
          token = generar_token()
          nuevo_estado = %{estado | conectados: Map.put(estado.conectados, usuario, token)}
          {:reply, {:ok, :autenticado, existente, token}, nuevo_estado}
        else
          {:reply, {:error, "Contraseña incorrecta para #{usuario}"}, estado}
        end

      :error ->
        registrar_nuevo(usuario, contrasena, tipo, zona, nombre, estado)
    end
  end

  def handle_call({:desconectar, usuario, token}, _from, estado) do
    if sesion_valida?(estado, usuario, token) do
      {:reply, :ok, %{estado | conectados: Map.delete(estado.conectados, usuario)}}
    else
      {:reply, {:error, "Sesión no válida o cerrada. Conéctese nuevamente con connect."}, estado}
    end
  end

  def handle_call({:cambiar_rol, quien, usuario, tipo}, _from, estado) do
    with {:ok, actor} <- buscar(estado, quien),
         {:ok, objetivo} <- buscar(estado, usuario),
         :ok <- validar_cambio_rol(estado.usuarios, actor, objetivo, tipo) do
      actualizado = %{objetivo | tipo: tipo}
      nuevo_estado = %{estado | usuarios: Map.put(estado.usuarios, usuario, actualizado)}
      guardar(nuevo_estado)
      {:reply, {:ok, actualizado}, nuevo_estado}
    else
      {:error, mensaje} -> {:reply, {:error, mensaje}, estado}
    end
  end

  def handle_call({:validar_sesion, usuario, token}, _from, estado) do
    if sesion_valida?(estado, usuario, token) do
      {:reply, {:ok, Map.fetch!(estado.usuarios, usuario)}, estado}
    else
      {:reply, {:error, "Sesión no válida o cerrada. Conéctese nuevamente con connect."}, estado}
    end
  end

  def handle_call(:listar, _from, estado) do
    lista =
      estado.usuarios
      |> Map.values()
      |> Enum.sort_by(fn u -> u.usuario end)
      |> Enum.map(fn u -> {u, Map.has_key?(estado.conectados, u.usuario)} end)

    {:reply, lista, estado}
  end

  # Solo el primer usuario puede registrarse con un rol privilegiado;
  # después el registro crea ciudadanos y los roles se asignan con set_role.
  defp registrar_nuevo(usuario, contrasena, tipo, zona, nombre, estado) do
    cond do
      tipo == "administrador" and existe_administrador?(estado.usuarios) ->
        {:reply, {:error, "Ya existe un administrador; no se puede registrar otro automáticamente"},
         estado}

      Usuario.nivel(tipo) > Usuario.nivel("ciudadano") and existe_coordinacion?(estado.usuarios) ->
        {:reply,
         {:error,
          "El registro automático solo crea ciudadanos. Conéctese sin tipo (o como ciudadano) " <>
            "y pida a un coordinador que le asigne el rol #{tipo} con set_role."}, estado}

      true ->
        crear_y_conectar(usuario, contrasena, tipo, zona, nombre, estado)
    end
  end

  defp crear_y_conectar(usuario, contrasena, tipo, zona, nombre, estado) do
    case Usuario.crear(usuario, contrasena, nombre, tipo, zona) do
      {:ok, nuevo} ->
        token = generar_token()

        nuevo_estado = %{
          usuarios: Map.put(estado.usuarios, usuario, nuevo),
          conectados: Map.put(estado.conectados, usuario, token)
        }

        guardar(nuevo_estado)
        {:reply, {:ok, :registrado, nuevo, token}, nuevo_estado}

      {:error, mensaje} ->
        {:reply, {:error, mensaje}, estado}
    end
  end

  defp validar_cambio_rol(usuarios, actor, objetivo, tipo) do
    nivel_actor = Usuario.nivel(actor.tipo)

    cond do
      tipo not in Usuario.tipos() ->
        {:error, "Tipo de usuario inválido. Use: #{Enum.join(Usuario.tipos(), ", ")}"}

      actor.usuario == objetivo.usuario ->
        {:error, "No puede cambiar su propio rol"}

      Usuario.nivel(tipo) > nivel_actor ->
        {:error, "Un #{actor.tipo} no puede otorgar el rol #{tipo}"}

      Usuario.nivel(objetivo.tipo) > nivel_actor ->
        {:error, "Un #{actor.tipo} no puede modificar a un #{objetivo.tipo}"}

      tipo == "administrador" and existe_administrador?(usuarios) ->
        {:error, "Ya existe un administrador"}

      true ->
        :ok
    end
  end

  defp sesion_valida?(estado, usuario, token) do
    token != nil and Map.get(estado.conectados, usuario) == token
  end

  defp buscar(estado, usuario) do
    case Map.fetch(estado.usuarios, usuario) do
      {:ok, encontrado} -> {:ok, encontrado}
      :error -> {:error, "No existe el usuario #{usuario}"}
    end
  end

  defp existe_administrador?(usuarios) do
    Enum.any?(Map.values(usuarios), fn u -> u.tipo == "administrador" end)
  end

  defp existe_coordinacion?(usuarios) do
    Enum.any?(Map.values(usuarios), fn u -> Usuario.nivel(u.tipo) >= Usuario.nivel("coordinador") end)
  end

  defp generar_token, do: :crypto.strong_rand_bytes(8) |> Base.encode16()

  # Vuelve a cifrar con sal las contraseñas guardadas con el formato antiguo.
  defp migrar_contrasena(estado, usuario, contrasena) do
    if Usuario.requiere_actualizacion?(usuario) do
      actualizado = %{usuario | contrasena: Usuario.cifrar(contrasena)}
      nuevo_estado = %{estado | usuarios: Map.put(estado.usuarios, usuario.usuario, actualizado)}
      guardar(nuevo_estado)
      nuevo_estado
    else
      estado
    end
  end

  defp guardar(estado) do
    Persistencia.guardar(@archivo, Map.values(estado.usuarios), &Usuario.a_campos/1)
  end
end
