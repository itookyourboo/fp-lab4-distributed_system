import Config

port = System.get_env("TASKER_PORT", "8181")
config :tasker, port: String.to_integer(port)
