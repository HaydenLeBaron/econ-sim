defmodule EconSim.Application do
  @moduledoc false
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      EconSimWeb.Telemetry,
      {Phoenix.PubSub, name: EconSim.PubSub},
      EconSim.Simulation,
      EconSimWeb.Endpoint
    ]

    opts = [strategy: :one_for_one, name: EconSim.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def config_change(changed, _new, removed) do
    EconSimWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
