# Entrega1/probar_ranking.exs
Code.require_file("datos.exs", __DIR__)
Code.require_file("lib/validacion.ex", __DIR__)
Code.require_file("lib/liquidacion.ex", __DIR__)
Code.require_file("lib/reportes.ex", __DIR__)

# Cargar datos y calcular liquidaciones
recolectores = Datos.recolectores()
lotes = Datos.lotes()
pesajes = Datos.pesajes()

pesajes_validos = 
  Enum.filter(pesajes, fn p -> 
    case Validacion.validar_pesaje(p, recolectores, lotes) do
      {:ok, _} -> true
      _ -> false
    end
  end)

liquidaciones = Liquidacion.liquidar(recolectores, lotes, pesajes_validos)

IO.puts("--- PRUEBA 1: ranking sin opciones ---")
IO.inspect(Reportes.ranking(liquidaciones, []))

IO.puts("\n--- PRUEBA 2: ranking por kilos, limite 3 ---")
IO.inspect(Reportes.ranking(liquidaciones, campo: :kilos, limite: 3))

IO.puts("\n--- PRUEBA 3: ranking ascendente por bruto ---")
IO.inspect(Reportes.ranking(liquidaciones, orden: :asc, campo: :bruto))