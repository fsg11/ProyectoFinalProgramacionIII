import Config

# Carpeta de los archivos de texto plano.
if config_env() == :test do
  config :emergencias, directorio_datos: "datos_test"
  config :logger, level: :warning
else
  config :emergencias, directorio_datos: "datos"
end

# Interfaz web: solo escucha al iniciar con `mix phx.server`.
config :emergencias, EmergenciasWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  http: [ip: {127, 0, 0, 1}, port: if(config_env() == :test, do: 4002, else: 4000)],
  render_errors: [formats: [html: EmergenciasWeb.ErrorHTML], layout: false],
  pubsub_server: Emergencias.PubSub,
  live_view: [signing_salt: "Qm8xVb3kLr2PzT6w"],
  secret_key_base: "kX3v9Lq2Wm7Rz1Tp8Yb4Nc6Hd0Fg5Js2Ua7Ve3Xi9Ko1Lw4Qy8Zr6Mt2Sn5Pb0Ch7Dj3Fk9Gl1Hm4Ex6"

config :phoenix, :json_library, Jason
config :phoenix, :plug_init_mode, :runtime
