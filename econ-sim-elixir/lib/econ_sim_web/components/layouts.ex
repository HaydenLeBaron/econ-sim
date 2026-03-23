defmodule EconSimWeb.Layouts do
  use EconSimWeb, :html

  def root(assigns) do
    ~H"""
    <!DOCTYPE html>
    <html lang="en">
      <head>
        <meta charset="utf-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1" />
        <meta name="csrf-token" content={get_csrf_token()} />
        <title>Economic Simulation Engine</title>
        <style><%= raw(EconSimWeb.Styles.css()) %></style>
      </head>
      <body>
        <%= @inner_content %>
        <script type="module" src="/assets/app.js"></script>
      </body>
    </html>
    """
  end

  def app(assigns) do
    ~H"""
    <%= @inner_content %>
    """
  end
end
