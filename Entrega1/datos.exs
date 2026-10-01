defmodule Datos do
  # Datos temporales para pruebas. Este archivo sera reemplazado por el docente.

  def recolectores do
    [
      %{id: 1, nombre: "Ana Gomez"},
      %{id: 2, nombre: "Luis Perez"}
    ]
  end

  def lotes do
    [
      %{id: 1, nombre: "Lote Norte"},
      %{id: 2, nombre: "Lote Sur"}
    ]
  end

  def pesajes do
    [
      %{recolector_id: 1, lote_id: 1, dia: 1, kilos: 120},
      %{recolector_id: 2, lote_id: 2, dia: 1, kilos: 95}
    ]
  end
end
