defmodule Emergencias.Usuario do
  @moduledoc """
  Usuario del sistema. El tipo de usuario define qué comandos puede usar:
  cada tipo tiene un nivel y cada comando exige un nivel mínimo.
  """

  defstruct usuario: "", contrasena: "", nombre: "", tipo: "ciudadano", zona: ""

  @niveles %{"ciudadano" => 1, "voluntario" => 2, "coordinador" => 3, "administrador" => 4}

  def tipos, do: ["ciudadano", "voluntario", "coordinador", "administrador"]

  def nivel(tipo), do: Map.get(@niveles, tipo, 0)

  def crear(usuario, contrasena, nombre, tipo, zona) do
    cond do
      usuario == "" or contrasena == "" ->
        {:error, "El usuario y la contraseña son obligatorios"}

      String.length(contrasena) < 4 ->
        {:error, "La contraseña debe tener al menos 4 caracteres"}

      not Map.has_key?(@niveles, tipo) ->
        {:error, "Tipo de usuario inválido. Use: #{Enum.join(tipos(), ", ")}"}

      true ->
        {:ok,
         %Emergencias.Usuario{
           usuario: usuario,
           contrasena: cifrar(contrasena),
           nombre: nombre,
           tipo: tipo,
           zona: zona
         }}
    end
  end

  @algoritmo "pbkdf2_sha256"
  @iteraciones 100_000
  @bytes_sal 16
  @bytes_hash 32

  @doc """
  La contraseña nunca se guarda en texto plano. Se guarda como

      pbkdf2_sha256$iteraciones$sal$hash

  con una sal aleatoria distinta para cada contraseña: dos usuarios con la
  misma clave tienen hashes diferentes y no sirven tablas precalculadas.
  Las miles de iteraciones hacen costoso probar claves por fuerza bruta.
  """
  def cifrar(contrasena) do
    sal = :crypto.strong_rand_bytes(@bytes_sal)
    hash = derivar(contrasena, sal, @iteraciones)
    Enum.join([@algoritmo, @iteraciones, hex(sal), hex(hash)], "$")
  end

  def contrasena_valida?(usuario, contrasena) do
    case String.split(usuario.contrasena, "$") do
      [@algoritmo, iteraciones, sal, hash] ->
        with {iteraciones, ""} <- Integer.parse(iteraciones),
             {:ok, sal} <- Base.decode16(sal, case: :lower),
             {:ok, hash} <- Base.decode16(hash, case: :lower) do
          iguales?(derivar(contrasena, sal, iteraciones), hash)
        else
          _ -> false
        end

      # Formato anterior: SHA-256 sin sal (64 caracteres hexadecimales).
      [hash_antiguo] ->
        iguales?(hex(:crypto.hash(:sha256, contrasena)), hash_antiguo)

      _ ->
        false
    end
  end

  @doc "Indica si la contraseña guardada usa el formato antiguo y debe volver a cifrarse."
  def requiere_actualizacion?(usuario), do: not String.starts_with?(usuario.contrasena, @algoritmo <> "$")

  defp derivar(contrasena, sal, iteraciones),
    do: :crypto.pbkdf2_hmac(:sha256, contrasena, sal, iteraciones, @bytes_hash)

  defp hex(binario), do: Base.encode16(binario, case: :lower)

  # Comparación en tiempo constante.
  defp iguales?(a, b) when byte_size(a) == byte_size(b) do
    diferencia =
      Enum.zip(:binary.bin_to_list(a), :binary.bin_to_list(b))
      |> Enum.reduce(0, fn {x, y}, acumulado -> Bitwise.bor(acumulado, Bitwise.bxor(x, y)) end)

    diferencia == 0
  end

  defp iguales?(_a, _b), do: false

  def a_campos(u), do: [u.usuario, u.contrasena, u.nombre, u.tipo, u.zona]

  def desde_campos([usuario, contrasena, nombre, tipo, zona]) do
    %Emergencias.Usuario{
      usuario: usuario,
      contrasena: contrasena,
      nombre: nombre,
      tipo: tipo,
      zona: zona
    }
  end

  def desde_campos(_campos), do: nil

  defimpl String.Chars, for: Emergencias.Usuario do
    def to_string(u), do: "#{u.usuario} (#{u.nombre}) - #{u.tipo} - zona #{u.zona}"
  end
end
