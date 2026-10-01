Code.require_file("datos.exs", __DIR__)

defmodule Programa do
  # Modulo principal y punto de entrada del programa.

  def main do
    recolectores = Datos.recolectores()
    lotes = Datos.lotes()
    pesajes = Datos.pesajes()

    {pesajes_validos, pesajes_invalidos} = validar_pesajes(pesajes, recolectores, lotes)
    liquidaciones = Liquidacion.liquidar(recolectores, lotes, pesajes_validos)

    IO.puts("Liquidacion de la cosecha de una finca cafetera")
    imprimir_reportes(recolectores, lotes, pesajes_validos, pesajes_invalidos, liquidaciones)

    {pesajes_validos_actualizados, liquidaciones_actualizadas} =
      procesar_pesaje_adicional(recolectores, lotes, pesajes_validos)

    imprimir_desprendible(recolectores, lotes, pesajes_validos_actualizados, liquidaciones_actualizadas)
  end

  defp validar_pesajes(pesajes, recolectores, lotes) do
    {validos, invalidos} =
      Enum.reduce(pesajes, {[], []}, fn pesaje, {validos_acum, invalidos_acum} ->
        case Validacion.validar_pesaje(pesaje, recolectores, lotes) do
          {:ok, pesaje_valido} ->
            {[pesaje_valido | validos_acum], invalidos_acum}

          {:error, motivo} ->
            {validos_acum, [%{pesaje: pesaje, motivo: motivo} | invalidos_acum]}
        end
      end)

    {Enum.reverse(validos), Enum.reverse(invalidos)}
  end

  defp imprimir_reportes(recolectores, lotes, pesajes_validos, pesajes_invalidos, liquidaciones) do
    [
      Reportes.reporte_r1(pesajes_invalidos),
      Reportes.reporte_r2(lotes, pesajes_validos),
      Reportes.reporte_r3(pesajes_validos),
      Reportes.reporte_r4(liquidaciones),
      Reportes.reporte_r5(recolectores, pesajes_validos),
      Reportes.reporte_r6(recolectores, pesajes_validos),
      Reportes.reporte_r7(liquidaciones, pesajes_validos),
      Reportes.reporte_r8(recolectores, lotes, pesajes_validos)
    ]
    |> Enum.join("\n\n")
    |> IO.puts()
  end

  defp procesar_pesaje_adicional(recolectores, lotes, pesajes_validos) do
    entrada = IO.gets("Ingrese un pesaje adicional (recolector;lote dia kilos verdes) o Enter para omitir: ")

    case limpiar_entrada(entrada) do
      "" ->
        IO.puts("No se agrego ningun pesaje adicional.")
        liquidaciones = Liquidacion.liquidar(recolectores, lotes, pesajes_validos)
        {pesajes_validos, liquidaciones}

      linea ->
        case parsear_pesaje(linea) do
          {:ok, pesaje} ->
            agregar_pesaje_si_valido(pesaje, recolectores, lotes, pesajes_validos)

          {:error, :formato_invalido} ->
            IO.puts("Pesaje rechazado: formato_invalido")
            liquidaciones = Liquidacion.liquidar(recolectores, lotes, pesajes_validos)
            {pesajes_validos, liquidaciones}
        end
    end
  end

  defp agregar_pesaje_si_valido(pesaje, recolectores, lotes, pesajes_validos) do
    case Validacion.validar_pesaje(pesaje, recolectores, lotes) do
      {:ok, pesaje_valido} ->
        pesajes_actualizados = pesajes_validos ++ [pesaje_valido]
        liquidaciones = Liquidacion.liquidar(recolectores, lotes, pesajes_actualizados)
        IO.puts("Pesaje adicional agregado y liquidaciones recalculadas.")
        {pesajes_actualizados, liquidaciones}

      {:error, motivo} ->
        IO.puts("Pesaje rechazado: #{motivo}")
        liquidaciones = Liquidacion.liquidar(recolectores, lotes, pesajes_validos)
        {pesajes_validos, liquidaciones}
    end
  end

  defp parsear_pesaje(linea) do
    campos =
      linea
      |> String.replace(";", " ")
      |> String.split(" ", trim: true)

    case campos do
      [recolector, lote, dia_texto, kilos_texto, verdes_texto] ->
        with {:ok, dia} <- parsear_entero(dia_texto),
             {:ok, kilos} <- parsear_numero(kilos_texto),
             {:ok, verdes} <- parsear_numero(verdes_texto) do
          {:ok, %{recolector: recolector, lote: lote, dia: dia, kilos: kilos, verdes: verdes}}
        else
          {:error, :formato_invalido} -> {:error, :formato_invalido}
        end

      _ ->
        {:error, :formato_invalido}
    end
  end

  defp parsear_entero(texto) do
    case Integer.parse(texto) do
      {numero, ""} -> {:ok, numero}
      _ -> {:error, :formato_invalido}
    end
  end

  defp parsear_numero(texto) do
    case Float.parse(texto) do
      {numero, ""} -> {:ok, numero}
      _ -> {:error, :formato_invalido}
    end
  end

  defp imprimir_desprendible(recolectores, lotes, pesajes_validos, liquidaciones) do
    codigo =
      IO.gets("Ingrese el código del recolector para ver su desprendible: ")
      |> limpiar_entrada()

    case Enum.find(recolectores, fn recolector -> recolector.codigo == codigo end) do
      nil ->
        IO.puts("No existe un recolector con el código #{codigo}.")

      recolector ->
        pesajes_recolector =
          Enum.filter(pesajes_validos, fn pesaje -> pesaje.recolector == recolector.codigo end)

        liquidacion = Enum.find(liquidaciones, fn item -> item.codigo == recolector.codigo end)

        IO.puts(generar_desprendible(recolector, lotes, pesajes_recolector, liquidacion))
    end
  end

  defp generar_desprendible(recolector, lotes, pesajes_recolector, liquidacion) do
    dias_trabajados =
      pesajes_recolector
      |> Enum.map(fn pesaje -> pesaje.dia end)
      |> Enum.uniq()
      |> length()

    detalle_pesajes =
      pesajes_recolector
      |> Enum.with_index(1)
      |> Enum.map(fn {pesaje, indice} ->
        lote = Enum.find(lotes, fn item -> item.id == pesaje.lote end)
        nombre_lote = if lote == nil, do: pesaje.lote, else: lote.nombre
        valor = Liquidacion.calcular_valor_pesaje(pesaje)

        "#{indice}. Dia #{pesaje.dia} - #{pesaje.lote} #{nombre_lote}: #{formato_numero(pesaje.kilos)} kg, verdes #{formato_numero(pesaje.verdes)}%, valor #{moneda(valor)}"
      end)

    lineas_pesajes =
      if detalle_pesajes == [] do
        ["Sin pesajes validos en la semana."]
      else
        detalle_pesajes
      end

    [
      "Desprendible de pago",
      "Recolector: #{recolector.codigo} - #{recolector.nombre}",
      "Dias trabajados: #{dias_trabajados}",
      "Detalle de pesajes:",
      lineas_pesajes,
      "Kilos totales: #{formato_numero(liquidacion.kilos_totales)}",
      "Valor pesajes: #{moneda(liquidacion.valor_pesajes)}",
      "Bonificacion: #{moneda(liquidacion.bonificaciones)}",
      "Alimentacion: #{moneda(liquidacion.descuento_alimentacion)}",
      "Neto a pagar: #{moneda(liquidacion.neto)}"
    ]
    |> List.flatten()
    |> Enum.join("\n")
  end

  defp limpiar_entrada(nil), do: ""
  defp limpiar_entrada(entrada), do: String.trim(entrada)

  defp moneda(valor), do: "$#{formato_numero(valor)}"

  defp formato_numero(valor) do
    valor
    |> :erlang.float()
    |> :erlang.float_to_binary(decimals: 2)
  end
end

Programa.main()
