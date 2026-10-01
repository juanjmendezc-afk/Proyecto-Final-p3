defmodule Liquidacion do
  # Modulo encargado de calcular la liquidacion de la cosecha cafetera.

  @tarifa_base 1000
  @bonificacion_diaria 8000
  @kilos_meta_bonificacion 120
  @descuento_alimentacion 12000

  def calcular_valor_pesaje(pesaje) do
    pesaje.kilos * @tarifa_base * (1 + ajuste_por_verdes(pesaje.verdes))
  end

  def calcular_bonificacion_dia(pesajes_recolector, dia) do
    kilos_dia =
      pesajes_recolector
      |> Enum.filter(fn pesaje -> pesaje.dia == dia end)
      |> Enum.map(fn pesaje -> pesaje.kilos end)
      |> Enum.sum()

    if kilos_dia >= @kilos_meta_bonificacion do
      @bonificacion_diaria
    else
      0
    end
  end

  def calcular_descuento_alimentacion(recolector, pesajes_recolector) do
    if recolector.alimentacion do
      dias_trabajados(pesajes_recolector) * @descuento_alimentacion
    else
      0
    end
  end

  def liquidar(recolectores, _lotes, pesajes_validos) do
    Enum.map(recolectores, fn recolector ->
      pesajes_recolector =
        Enum.filter(pesajes_validos, fn pesaje -> pesaje.recolector == recolector.codigo end)

      kilos_totales = sumar_kilos(pesajes_recolector)
      valor_pesajes = sumar_valor_pesajes(pesajes_recolector)
      bonificaciones = sumar_bonificaciones(pesajes_recolector)
      descuento_alimentacion = calcular_descuento_alimentacion(recolector, pesajes_recolector)
      neto = valor_pesajes + bonificaciones - descuento_alimentacion

      %{
        codigo: recolector.codigo,
        nombre: recolector.nombre,
        kilos_totales: kilos_totales,
        valor_pesajes: valor_pesajes,
        bonificaciones: bonificaciones,
        descuento_alimentacion: descuento_alimentacion,
        neto: neto
      }
    end)
  end

  defp ajuste_por_verdes(verdes) when verdes <= 2, do: 0.05
  defp ajuste_por_verdes(verdes) when verdes <= 5, do: 0
  defp ajuste_por_verdes(verdes) when verdes <= 10, do: -0.10
  defp ajuste_por_verdes(_verdes), do: -0.30

  defp sumar_kilos(pesajes_recolector) do
    pesajes_recolector
    |> Enum.map(fn pesaje -> pesaje.kilos end)
    |> Enum.sum()
  end

  defp sumar_valor_pesajes(pesajes_recolector) do
    pesajes_recolector
    |> Enum.map(&calcular_valor_pesaje/1)
    |> Enum.sum()
  end

  defp sumar_bonificaciones(pesajes_recolector) do
    pesajes_recolector
    |> dias_trabajados_lista()
    |> Enum.map(fn dia -> calcular_bonificacion_dia(pesajes_recolector, dia) end)
    |> Enum.sum()
  end

  defp dias_trabajados(pesajes_recolector) do
    pesajes_recolector
    |> dias_trabajados_lista()
    |> length()
  end

  defp dias_trabajados_lista(pesajes_recolector) do
    pesajes_recolector
    |> Enum.map(fn pesaje -> pesaje.dia end)
    |> Enum.uniq()
  end
end
