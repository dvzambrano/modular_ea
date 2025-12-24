//+------------------------------------------------------------------+
//|                                                Signal_Pivots.mqh |
//|                                         CryptOrly Copyright 2025 |
//+------------------------------------------------------------------+
#include "Signal_Base.mqh"
#include "Visuals.mqh"

class CSignalPivots : public CSignal
{
private:
   int m_periodo; // Cuántas velas atrás usamos para el cálculo (o timeframe)

   // Variables para guardar los niveles calculados
   double m_P, m_R1, m_R2, m_S1, m_S2;
   datetime m_lastCalcTime; // Para no recalcular en cada tick, solo en cada vela

public:
   // Constructor
   CSignalPivots(int periodo)
   {
      m_periodo = periodo;
      m_lastCalcTime = 0;
      m_P = 0;
      m_R1 = 0;
      m_R2 = 0;
      m_S1 = 0;
      m_S2 = 0;
   }

   // Destructor: Limpieza de líneas
   ~CSignalPivots()
   {
      ObjectsDeleteAll(0, "Pivot_Line_");
      ObjectsDeleteAll(0, "Pivot_Text_");
   }

   // Inicialización
   bool Init() override
   {
      // Calculamos los niveles iniciales
      CalcularNiveles();
      return true;
   }

   // --- CÁLCULO MATEMÁTICO ---
   void CalcularNiveles()
   {
      // Evitamos recalcular innecesariamente dentro de la misma vela
      datetime currentBarTime = iTime(_Symbol, _Period, 0);
      if (m_lastCalcTime == currentBarTime)
         return;

      m_lastCalcTime = currentBarTime;

      // Usamos los datos de la vela anterior (High, Low, Close) para calcular
      // Nota: Si periodo > 1, esto busca el H/L/C del rango definido.
      // Para simplificar y hacerlo estándar, usaremos la vela [1] diaria o del periodo actual.

      double H = iHigh(_Symbol, _Period, 1);
      double L = iLow(_Symbol, _Period, 1);
      double C = iClose(_Symbol, _Period, 1);

      // Fórmulas Clásicas de Pivot Points
      m_P = (H + L + C) / 3.0;
      m_R1 = (2.0 * m_P) - L;
      m_S1 = (2.0 * m_P) - H;
      m_R2 = m_P + (H - L);
      m_S2 = m_P - (H - L);
   }

   // --- VISUALIZACIÓN (ON TIMER) ---
   void OnTimerVisuals() override
   {
      // Aseguramos que los niveles estén frescos
      CalcularNiveles();

      // Dibujamos las líneas en el gráfico principal (Ventana 0)

      // 1. PIVOTE CENTRAL (Amarillo/Dorado)
      DibujarLineaNivel("Pivot_Line_P", m_P, clrGold, STYLE_SOLID, 2);
      DibujarEtiqueta("Pivot_Text_P", m_P, clrGold, "PIVOT");

      // 2. RESISTENCIAS (Rojo)
      DibujarLineaNivel("Pivot_Line_R1", m_R1, clrOrangeRed, STYLE_DASH, 1);
      DibujarEtiqueta("Pivot_Text_R1", m_R1, clrOrangeRed, "R1");

      DibujarLineaNivel("Pivot_Line_R2", m_R2, clrRed, STYLE_DASH, 1);
      DibujarEtiqueta("Pivot_Text_R2", m_R2, clrRed, "R2");

      // 3. SOPORTES (Azul/Verde)
      DibujarLineaNivel("Pivot_Line_S1", m_S1, clrCornflowerBlue, STYLE_DASH, 1);
      DibujarEtiqueta("Pivot_Text_S1", m_S1, clrCornflowerBlue, "S1");

      DibujarLineaNivel("Pivot_Line_S2", m_S2, clrBlue, STYLE_DASH, 1);
      DibujarEtiqueta("Pivot_Text_S2", m_S2, clrBlue, "S2");
   }

   // Helper para dibujar líneas horizontales infinitas
   void DibujarLineaNivel(string name, double price, color clr, ENUM_LINE_STYLE style, int width)
   {
      if (ObjectFind(0, name) < 0)
      {
         ObjectCreate(0, name, OBJ_HLINE, 0, 0, price);
         ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
         ObjectSetInteger(0, name, OBJPROP_STYLE, style);
         ObjectSetInteger(0, name, OBJPROP_WIDTH, width);
         ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
         ObjectSetInteger(0, name, OBJPROP_BACK, true); // Detrás de las velas
      }
      else
      {
         ObjectSetDouble(0, name, OBJPROP_PRICE, price);
      }
   }

   // Helper para poner texto a la derecha
   void DibujarEtiqueta(string name, double price, color clr, string text)
   {
      if (ObjectFind(0, name) < 0)
      {
         // Usamos OBJ_TEXT en el futuro cercano para que esté a la derecha
         ObjectCreate(0, name, OBJ_TEXT, 0, TimeCurrent() + PeriodSeconds() * 5, price);
         ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
         ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_LEFT_LOWER);
         ObjectSetString(0, name, OBJPROP_TEXT, "  " + text);
         ObjectSetString(0, name, OBJPROP_FONT, "Arial");
         ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 8);
      }
      else
      {
         // Actualizamos posición (siempre un poco a la derecha del precio actual)
         ObjectSetDouble(0, name, OBJPROP_PRICE, price);
         ObjectSetInteger(0, name, OBJPROP_TIME, TimeCurrent() + PeriodSeconds() * 2);
      }
   }

   // LÓGICA DE TRADING (Rebote en Niveles)
   int ObtenerSenal() override
   {
      CalcularNiveles(); // Asegurar datos frescos

      double close = iClose(_Symbol, _Period, 0);
      double open = iOpen(_Symbol, _Period, 0);

      // ESTRATEGIA SIMPLE DE REBOTE

      // 1. Compra: El precio toca S1 desde arriba y rebota (vela verde)
      // Low tocó S1, pero Close cerró arriba
      if (iLow(_Symbol, _Period, 0) <= m_S1 && close > m_S1 && close > open)
      {
         return 1;
      }

      // 2. Venta: El precio toca R1 desde abajo y rebota (vela roja)
      // High tocó R1, pero Close cerró abajo
      if (iHigh(_Symbol, _Period, 0) >= m_R1 && close < m_R1 && close < open)
      {
         return -1;
      }

      return 0;
   }
};