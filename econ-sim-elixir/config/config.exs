import Config

config :econ_sim,
  generators: [timestamp_type: :utc_datetime]

config :econ_sim, EconSimWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Phoenix.Endpoint.Cowboy2Adapter,
  render_errors: [
    formats: [html: EconSimWeb.ErrorHTML],
    layout: false
  ],
  pubsub_server: EconSim.PubSub,
  live_view: [signing_salt: "econ_sim_salt"]

config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

config :phoenix, :json_library, Jason

import_config "#{config_env()}.exs"
