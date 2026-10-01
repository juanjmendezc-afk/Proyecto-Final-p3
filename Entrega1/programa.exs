Code.require_file("datos.exs", __DIR__)

defmodule Programa do
  # Modulo principal y punto de entrada del programa.

  def main do
    IO.puts("Liquidacion de la cosecha de una finca cafetera")
    IO.inspect(Datos.recolectores(), label: "Recolectores")
    IO.inspect(Datos.lotes(), label: "Lotes")
    IO.inspect(Datos.pesajes(), label: "Pesajes")
  end
end

Programa.main()
