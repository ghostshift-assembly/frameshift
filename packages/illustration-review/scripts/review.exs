[renderer, fixture, destination] = System.argv()

case Frameshift.Illustration.Review.run(
       renderer: renderer,
       fixture: fixture,
       destination: destination
     ) do
  {:ok, manifest} ->
    IO.puts("Completed producer/document join: #{manifest["generation_id"]}")

  {:error, reason} ->
    IO.inspect(reason, label: "Illustration review refused")
    System.halt(2)
end
