defmodule Reportes do
  # Modulo encargado de generar y mostrar reportes en consola.

  @dias_cosecha 1..6
  @meta_diaria 400

  def reporte_r1(pesajes_invalidos) do
    detalle =
      pesajes_invalidos
      |> Enum.with_index(1)
      |> Enum.map(fn {rechazo, indice} ->
        %{pesaje: pesaje, motivo: motivo} = normalizar_rechazo(rechazo)
        "#{indice}. motivo=#{motivo} pesaje=#{inspect(pesaje)}"
      end)

    resumen =
      pesajes_invalidos
      |> Enum.map(fn rechazo -> normalizar_rechazo(rechazo).motivo end)
      |> Enum.frequencies()
      |> Enum.sort_by(fn {motivo, _cantidad} -> to_string(motivo) end)
      |> Enum.map(fn {motivo, cantidad} -> "#{motivo}: #{cantidad}" end)

    unir_lineas([
      "R1 - Pesajes rechazados",
      "Detalle:",
      lineas_o_mensaje(detalle, "No hay pesajes rechazados."),
      "Resumen por motivo:",
      lineas_o_mensaje(resumen, "No hay rechazos acumulados.")
    ])
  end

  def reporte_r2(lotes, pesajes_validos) do
    lineas =
      lotes
      |> Enum.map(fn lote ->
        kilos = kilos_lote(pesajes_validos, lote.id)
        rendimiento = dividir_seguro(kilos, lote.hectareas)

        %{
          lote: lote,
          kilos: kilos,
          rendimiento: rendimiento
        }
      end)
      |> Enum.sort_by(fn fila -> fila.rendimiento end, :desc)
      |> Enum.map(fn fila ->
        "#{fila.lote.id} - #{fila.lote.nombre}: #{formato_numero(fila.kilos)} kg, #{formato_numero(fila.rendimiento)} kg/ha"
      end)

    unir_lineas(["R2 - Kilos por lote y rendimiento", lineas_o_mensaje(lineas, "No hay lotes.")])
  end

  def reporte_r3(pesajes_validos) do
    datos_dias =
      for dia <- @dias_cosecha do
        kilos = kilos_dia(pesajes_validos, dia)
        cumple = kilos >= @meta_diaria

        %{dia: dia, kilos: kilos, cumple: cumple}
      end

    lineas =
      Enum.map(datos_dias, fn dato ->
        estado = if dato.cumple, do: "cumple", else: "no cumple"
        "Dia #{dato.dia}: #{formato_numero(dato.kilos)} kg - #{estado}"
      end)

    cumple_todos = Enum.all?(datos_dias, fn dato -> dato.cumple end)
    cumple_alguno = Enum.any?(datos_dias, fn dato -> dato.cumple end)

    unir_lineas([
      "R3 - Meta diaria de la finca",
      lineas,
      "Cumplio la meta todos los dias: #{si_no(cumple_todos)}",
      "Cumplio la meta al menos un dia: #{si_no(cumple_alguno)}"
    ])
  end

  def reporte_r4(liquidaciones) do
    lineas =
      liquidaciones
      |> Enum.sort_by(fn liquidacion -> liquidacion.neto end, :desc)
      |> Enum.with_index(1)
      |> Enum.map(fn {liquidacion, indice} ->
        "#{indice}. #{liquidacion.codigo} - #{liquidacion.nombre}: kilos=#{formato_numero(liquidacion.kilos_totales)}, pesajes=#{moneda(liquidacion.valor_pesajes)}, bonificaciones=#{moneda(liquidacion.bonificaciones)}, alimentacion=#{moneda(liquidacion.descuento_alimentacion)}, neto=#{moneda(liquidacion.neto)}"
      end)

    unir_lineas(["R4 - Liquidacion de recolectores", lineas_o_mensaje(lineas, "No hay liquidaciones.")])
  end

  def reporte_r5(recolectores, pesajes_validos) do
    mejores_por_dia =
      for dia <- @dias_cosecha do
        mejores = mejores_recolectores_dia(recolectores, pesajes_validos, dia)
        %{dia: dia, mejores: mejores}
      end

    lineas_dias =
      Enum.map(mejores_por_dia, fn dato ->
        nombres = nombres_recolectores(dato.mejores)
        "Dia #{dato.dia}: #{nombres}"
      end)

    conteo_mejores =
      mejores_por_dia
      |> Enum.flat_map(fn dato -> Enum.map(dato.mejores, fn recolector -> recolector.codigo end) end)
      |> Enum.frequencies()

    ganadores_semana = ganadores_por_frecuencia(recolectores, conteo_mejores)

    unir_lineas([
      "R5 - Mejor recolector por dia",
      lineas_dias,
      "Mejor de la semana: #{nombres_recolectores(ganadores_semana)}"
    ])
  end

  def reporte_r6(recolectores, pesajes_validos) do
    candidatos =
      recolectores
      |> Enum.map(fn recolector ->
        pesajes_recolector = pesajes_de_recolector(pesajes_validos, recolector.codigo)

        %{
          recolector: recolector,
          cantidad_pesajes: length(pesajes_recolector),
          calidad: calidad_ponderada(pesajes_recolector)
        }
      end)
      |> Enum.filter(fn dato -> dato.cantidad_pesajes >= 3 end)
      |> Enum.sort_by(fn dato -> dato.calidad end, :asc)

    case candidatos do
      [] ->
        unir_lineas(["R6 - Mejor calidad", "No hay recolectores con al menos 3 pesajes validos."])

      [mejor | _] ->
        empatados = Enum.filter(candidatos, fn dato -> dato.calidad == mejor.calidad end)
        nombres = Enum.map(empatados, fn dato -> dato.recolector end) |> nombres_recolectores()

        unir_lineas([
          "R6 - Mejor calidad",
          "Recolector(es): #{nombres}",
          "Porcentaje ponderado de verdes: #{formato_numero(mejor.calidad)}%"
        ])
    end
  end

  def reporte_r7(liquidaciones, pesajes_validos) do
    total_pagado = liquidaciones |> Enum.map(fn liquidacion -> liquidacion.neto end) |> Enum.sum()
    kilos_validos = pesajes_validos |> Enum.map(fn pesaje -> pesaje.kilos end) |> Enum.sum()
    costo_promedio = dividir_seguro(total_pagado, kilos_validos)

    unir_lineas([
      "R7 - Total pagado y costo promedio",
      "Total pagado en la semana: #{moneda(total_pagado)}",
      "Kilos validos: #{formato_numero(kilos_validos)}",
      "Costo promedio por kilo: #{moneda(costo_promedio)}"
    ])
  end

  def reporte_r8(recolectores, lotes, pesajes_validos) do
    lotes_requeridos = Enum.map(lotes, fn lote -> lote.id end) |> MapSet.new()

    recolectores_todos_lotes =
      Enum.filter(recolectores, fn recolector ->
        lotes_recolector =
          pesajes_validos
          |> pesajes_de_recolector(recolector.codigo)
          |> Enum.map(fn pesaje -> pesaje.lote end)
          |> MapSet.new()

        MapSet.subset?(lotes_requeridos, lotes_recolector)
      end)

    unir_lineas([
      "R8 - Recolectores en todos los lotes",
      nombres_recolectores(recolectores_todos_lotes)
    ])
  end

  def ranking(liquidaciones, opciones \\ []) do
    campo = Keyword.get(opciones, :campo, :neto)
    orden = Keyword.get(opciones, :orden, :desc)
    limite = Keyword.get(opciones, :limite, :todos)

    liquidaciones
    |> Enum.sort_by(fn liquidacion -> valor_ranking(liquidacion, campo) end, orden_ranking(orden))
    |> aplicar_limite(limite)
  end

  defp normalizar_rechazo(%{pesaje: pesaje, motivo: motivo}), do: %{pesaje: pesaje, motivo: motivo}
  defp normalizar_rechazo({pesaje, motivo}), do: %{pesaje: pesaje, motivo: motivo}
  defp normalizar_rechazo({:error, motivo, pesaje}), do: %{pesaje: pesaje, motivo: motivo}
  defp normalizar_rechazo(rechazo), do: %{pesaje: rechazo, motivo: :motivo_desconocido}

  defp kilos_lote(pesajes_validos, lote_id) do
    pesajes_validos
    |> Enum.filter(fn pesaje -> pesaje.lote == lote_id end)
    |> Enum.map(fn pesaje -> pesaje.kilos end)
    |> Enum.sum()
  end

  defp kilos_dia(pesajes_validos, dia) do
    pesajes_validos
    |> Enum.filter(fn pesaje -> pesaje.dia == dia end)
    |> Enum.map(fn pesaje -> pesaje.kilos end)
    |> Enum.sum()
  end

  defp mejores_recolectores_dia(recolectores, pesajes_validos, dia) do
    datos =
      recolectores
      |> Enum.map(fn recolector ->
        kilos =
          pesajes_validos
          |> Enum.filter(fn pesaje -> pesaje.recolector == recolector.codigo and pesaje.dia == dia end)
          |> Enum.map(fn pesaje -> pesaje.kilos end)
          |> Enum.sum()

        %{recolector: recolector, kilos: kilos}
      end)

    maximo = datos |> Enum.map(fn dato -> dato.kilos end) |> Enum.max(fn -> 0 end)

    datos
    |> Enum.filter(fn dato -> dato.kilos == maximo and maximo > 0 end)
    |> Enum.map(fn dato -> dato.recolector end)
  end

  defp ganadores_por_frecuencia(recolectores, frecuencias) do
    maximo = frecuencias |> Map.values() |> Enum.max(fn -> 0 end)

    recolectores
    |> Enum.filter(fn recolector -> Map.get(frecuencias, recolector.codigo, 0) == maximo and maximo > 0 end)
  end

  defp pesajes_de_recolector(pesajes_validos, codigo) do
    Enum.filter(pesajes_validos, fn pesaje -> pesaje.recolector == codigo end)
  end

  defp calidad_ponderada(pesajes_recolector) do
    kilos = pesajes_recolector |> Enum.map(fn pesaje -> pesaje.kilos end) |> Enum.sum()

    verdes_por_kilos =
      pesajes_recolector
      |> Enum.map(fn pesaje -> pesaje.verdes * pesaje.kilos end)
      |> Enum.sum()

    dividir_seguro(verdes_por_kilos, kilos)
  end

  defp nombres_recolectores([]), do: "No hay ninguno."

  defp nombres_recolectores(recolectores) do
    recolectores
    |> Enum.map(fn recolector -> "#{recolector.codigo} - #{recolector.nombre}" end)
    |> Enum.join(", ")
  end

  defp valor_ranking(liquidacion, :neto), do: liquidacion.neto
  defp valor_ranking(liquidacion, :kilos), do: liquidacion.kilos_totales
  defp valor_ranking(liquidacion, :bruto), do: liquidacion.valor_pesajes
  defp valor_ranking(liquidacion, _campo), do: liquidacion.neto

  defp orden_ranking(:asc), do: :asc
  defp orden_ranking(_orden), do: :desc

  defp aplicar_limite(liquidaciones, limite) when is_integer(limite) and limite > 0 do
    Enum.take(liquidaciones, limite)
  end

  defp aplicar_limite(liquidaciones, _limite), do: liquidaciones

  defp dividir_seguro(_numerador, 0), do: 0
  defp dividir_seguro(numerador, denominador), do: numerador / denominador

  defp lineas_o_mensaje([], mensaje), do: mensaje
  defp lineas_o_mensaje(lineas, _mensaje), do: lineas

  defp unir_lineas(partes) do
    partes
    |> List.flatten()
    |> Enum.join("\n")
  end

  defp moneda(valor), do: "$#{formato_numero(valor)}"

  defp formato_numero(valor) do
    valor
    |> :erlang.float()
    |> :erlang.float_to_binary(decimals: 2)
  end

  defp si_no(true), do: "si"
  defp si_no(false), do: "no"
end
