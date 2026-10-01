defmodule Validacion do
  # Modulo encargado de validar los datos de recolectores, lotes y pesajes.

  def validar_pesaje(pesaje, recolectores, lotes) do
    with {:ok, _recolector} <- validar_recolector(pesaje, recolectores),
         {:ok, _lote} <- validar_lote(pesaje, lotes),
         {:ok, _dia} <- validar_dia(pesaje),
         {:ok, _kilos} <- validar_kilos(pesaje),
         {:ok, _verdes} <- validar_verdes(pesaje) do
      {:ok, pesaje}
    end
  end

  defp validar_recolector(pesaje, recolectores) do
    existe = Enum.any?(recolectores, fn recolector -> recolector.codigo == pesaje.recolector end)

    if existe do
      {:ok, pesaje.recolector}
    else
      {:error, :recolector_desconocido}
    end
  end

  defp validar_lote(pesaje, lotes) do
    existe = Enum.any?(lotes, fn lote -> lote.id == pesaje.lote end)

    if existe do
      {:ok, pesaje.lote}
    else
      {:error, :lote_desconocido}
    end
  end

  defp validar_dia(pesaje) do
    if is_integer(pesaje.dia) and pesaje.dia >= 1 and pesaje.dia <= 6 do
      {:ok, pesaje.dia}
    else
      {:error, :dia_invalido}
    end
  end

  defp validar_kilos(pesaje) do
    if is_number(pesaje.kilos) and pesaje.kilos > 0 and pesaje.kilos <= 250 do
      {:ok, pesaje.kilos}
    else
      {:error, :kilos_fuera_de_rango}
    end
  end

  defp validar_verdes(pesaje) do
    if is_number(pesaje.verdes) and pesaje.verdes >= 0 and pesaje.verdes <= 100 do
      {:ok, pesaje.verdes}
    else
      {:error, :porcentaje_invalido}
    end
  end
end
