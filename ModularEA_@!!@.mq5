//+------------------------------------------------------------------+
//|                                                   ModularEA.mq5  |
//|                                         CryptOrly Copyright 2025 |
//+------------------------------------------------------------------+
#property copyright "CryptOrly Copyright 2025"
#property link "https://www.cryptorly.eu"
#property version "14.40" // TFM REFACTORED (FULL CODE)
#property strict

// =============================================================
// 1. INCLUDES
// =============================================================
// Importamos la librería estándar de comercio
#include <Trade\Trade.mqh>

// Importamos nuestros módulos de estrategias (Signals)
#include "Signal_Base.mqh"
#include "Signal_EMA.mqh"
#include "Signal_Pivots.mqh"
#include "Signal_RSI.mqh"
#include "Signal_CCI.mqh" // <--- NUEVO: Necesario para TFM Refactorizado
#include "Signal_TrendFlatMomentum.mqh"
#include "Signal_AdaptiveQ.mqh"

// Importamos la estrategia Combo Refactorizada
#include "Signal_Combo_EMA_RSI.mqh"

// Importamos los módulos de soporte (El Chasis del Ferrari)
#include "Risk.mqh"
#include "Execution.mqh"
#include "TradeManagement.mqh"
#include "TimeFilter.mqh"
#include "Visuals.mqh"

// =============================================================
// 2. ENUMS Y INPUTS
// =============================================================
// Lista desplegable para seleccionar la estrategia activa
enum TipoEstrategia
{
   ESTRATEGIA_CRUCE_EMA,     // Cruce de EMAs
   ESTRATEGIA_PIVOTS,        // Pivots
   ESTRATEGIA_RSI,           // RSI
   ESTRATEGIA_COMBO_EMA_RSI, // Combinacion EMAs + RSI
   ESTRATEGIA_BOLLINGER,     // Bandas de Bollinger
   ESTRATEGIA_TFM,           // Trend Flat Momentum
   ESTRATEGIA_ADAPTIVE_Q     // Q-Learning (IA Básica)
};

input group "=== CONFIGURACIÓN PRINCIPAL ===" input TipoEstrategia Estrategia = ESTRATEGIA_TFM; // Estrategia por defecto
input ulong MagicNumber = 123456;                                                               // ID único para identificar las órdenes de este bot
input string ComentarioOrden = "ModularEA POO";                                                 // Comentario que sale en el historial
input int Slippage = 5;                                                                         // Deslizamiento máximo permitido en puntos
input int MaxSpreadPoints = 30;                                                                 // Filtro: Si el spread es mayor a esto, no operamos
input bool MostrarPanel = true;                                                                 // Mostrar/Ocultar el panel de información en pantalla

input group "=== RIESGO (RISK) ===" input double RiskPercent = 1.0; // Porcentaje de la cuenta a arriesgar por operación
input double RewardRatio = 2.0;                                     // Ratio Beneficio:Riesgo (ej: 2.0 significa buscar ganar el doble de lo arriesgado)

// Configuración de Stop Loss Híbrido
input bool UsarSL_Estructural = true; // true = Usar Pivots (High/Low), false = Usar Puntos Fijos
input int Pivot_Periodo = 20;         // Cuántas velas atrás mirar para encontrar el Pivot (Soporte/Resistencia)
input int Pivot_Padding = 10;         // Puntos extra de margen (colchón) para el SL
input int SL_PuntosFijos = 150;       // Puntos de SL fijos (Solo se usa si UsarSL_Estructural es false)

input group "=== GESTIÓN DE POSICIONES ===" input bool UsarBreakEven = true; // Mover SL a entrada cuando el precio avanza
input bool BreakEvenReal = true;                                             // true = Asegurar ganancia (Entry + Offset), false = Solo Entry
input double BE_Trigger_Pts = 100;                                           // Puntos de ganancia necesarios para activar BreakEven
input double BE_Offset_Pts = 10;                                             // Puntos extra a favor para cubrir comisiones
input bool UsarTrailing = false;                                             // Perseguir el precio con el SL
input double TS_Distancia_Pts = 200;                                         // Distancia del Trailing Stop
input double TS_Step_Pts = 50;                                               // Cada cuántos puntos se actualiza el Trailing
input int MaxVelasTTL = 60;                                                  // Time To Live: Cerrar si pasan X velas sin tocar TP/SL

input group "=== HORARIOS Y DÍAS ===" input bool UsarHorario = true; // Activar filtro horario
input int HoraInicio_1 = 8;
input int MinInicio_1 = 0;
input int HoraFin_1 = 12;
input int MinFin_1 = 0;
input int HoraInicio_2 = 14;
input int MinInicio_2 = 0;
input int HoraFin_2 = 20;
input int MinFin_2 = 0;
input bool OpLunes = true;
input bool OpMartes = true;
input bool OpMiercoles = true;
input bool OpJueves = true;
input bool OpViernes = true;
input bool OpFinde = false;       // Operar fin de semana (para Crypto)
input bool EvitarRollover = true; // Evitar operar cerca de la medianoche (swaps altos)

input group "=== COLORES ===" input color Color_EMA_Rapida = clrLime; // Color para la EMA Rápida
input color Color_EMA_Lenta = clrRed;                                 // Color para la EMA Lenta
input color Color_RSI = clrDodgerBlue;                                // Color para la línea del RSI

input group "=== CRUCE EMAS (Params) ===" input int FastEMA = 9;
input int SlowEMA = 21;

input group "=== RSI (Params) ===" input int PeriodoRSI = 14;
input double NivelSobreCompraRSI = 70.0;
input double NivelSobreVentaRSI = 30.0;

input group "=== BOLLINGER BANDS ===" input int BB_Periodo = 20;
input double BB_Deviacion = 2.0;
input color BB_Color_Up = clrRed;
input color BB_Color_Low = clrLime;
input color BB_Color_Mid = clrWhite;

input group "=== PIVOTS ===" input int PeriodoPivots = 20;

input group "=== TREND FLAT MOMENTUM ===" input int TFM_MA_Fast = 11;
input int TFM_MA_Slow = 25;
input int TFM_RSI = 27;
input int TFM_CCI1 = 36;
input int TFM_CCI2 = 55; // (Reservado para futuro uso o doble CCI)

input group "=== ESTRATEGIA ADAPTIVE Q ===" input int AQ_Periodo = 14; // Periodo del ATR para volatilidad
input double AQ_Alpha = 0.5;                                           // Velocidad de aprendizaje (0.1 lento - 0.9 rápido)
input double AQ_Gamma = 0.5;                                           // Memoria a largo plazo

input group "=== ESTRATEGIA COMBO (EMA + RSI) ==="
    // Selecciona quién da la señal de entrada y quién filtra
    // Usamos el Enum específico del nuevo archivo combo
    input EnumModoCombo_EMA_RSI Combo_Modo = COMBO_EMA_GATILLO_RSI_FILTRO;

// =============================================================
// 3. VARIABLES GLOBALES
// =============================================================
CTrade trade;                     // Objeto para ejecución de órdenes
datetime lastBarTime = 0;         // Para controlar que solo operamos una vez por vela
CSignal *objetoEstrategia = NULL; // Puntero Polimórfico: Aquí vivirá nuestra estrategia (sea cual sea)

//+------------------------------------------------------------------+
//| ON INIT                                                          |
//| Se ejecuta una vez al cargar el EA                               |
//+------------------------------------------------------------------+
int OnInit()
{
   // Configuración inicial del objeto Trade
   trade.SetExpertMagicNumber(MagicNumber);
   trade.SetDeviationInPoints((ulong)Slippage);
   trade.SetTypeFilling(CExecution::GetFillingMode());
   trade.SetAsyncMode(false); // Modo síncrono para mayor seguridad

   // --- FACTORY (FÁBRICA DE ESTRATEGIAS) ---
   // Aquí decidimos qué "motor" le ponemos al Ferrari según el input del usuario
   switch (Estrategia)
   {
   case ESTRATEGIA_CRUCE_EMA:
      if (FastEMA >= SlowEMA)
      {
         Print("⛔ ERROR: FastEMA >= SlowEMA");
         return INIT_PARAMETERS_INCORRECT;
      }
      // Instanciamos estrategia simple de EMAs
      objetoEstrategia = new CSignalEMA(FastEMA, SlowEMA, Color_EMA_Rapida, Color_EMA_Lenta);
      break;

   case ESTRATEGIA_PIVOTS:
      if (PeriodoPivots < 2)
      {
         Print("⛔ ERROR: Pivots < 2");
         return INIT_PARAMETERS_INCORRECT;
      }
      // Instanciamos estrategia de Pivots
      objetoEstrategia = new CSignalPivots(PeriodoPivots);
      break;

   case ESTRATEGIA_RSI:
      // Instanciamos estrategia simple de RSI
      objetoEstrategia = new CSignalRSI(PeriodoRSI, NivelSobreCompraRSI, NivelSobreVentaRSI, Color_RSI);
      break;

   case ESTRATEGIA_BOLLINGER:
      objetoEstrategia = new CSignalBollinger(BB_Periodo, BB_Deviacion, BB_Color_Up, BB_Color_Low, BB_Color_Mid);
      break;

   case ESTRATEGIA_COMBO_EMA_RSI:
      // Instanciamos la estrategia COMBO (Composición Refactorizada)
      if (FastEMA >= SlowEMA)
      {
         Print("⛔ ERROR: FastEMA >= SlowEMA");
         return INIT_PARAMETERS_INCORRECT;
      }

      // Pasamos TODOS los parámetros necesarios para que construya sus hijos internamente
      // IMPORTANTE: Usamos la nueva clase CSignalCombo_EMA_RSI
      objetoEstrategia = new CSignalCombo_EMA_RSI(
          Combo_Modo,
          FastEMA, SlowEMA, Color_EMA_Rapida, Color_EMA_Lenta,
          PeriodoRSI, NivelSobreCompraRSI, NivelSobreVentaRSI, Color_RSI);
      break;

   case ESTRATEGIA_TFM:
      // Instanciamos TFM Refactorizado (Usa Composición EMA + RSI + CCI)
      if (TFM_MA_Fast >= TFM_MA_Slow)
      {
         Print("⛔ ERROR: TFM Fast >= Slow");
         return INIT_PARAMETERS_INCORRECT;
      }

      objetoEstrategia = new CSignalTrendFlatMomentum(
          TFM_MA_Fast, TFM_MA_Slow, TFM_RSI, TFM_CCI1,
          Color_EMA_Rapida, Color_EMA_Lenta, clrOrange // Color CCI Naranja por defecto
      );
      break;

   case ESTRATEGIA_ADAPTIVE_Q:
      objetoEstrategia = new CSignalAdaptiveQ(AQ_Periodo, AQ_Alpha, AQ_Gamma);
      break;
   }

   // Validaciones de Seguridad
   if (objetoEstrategia == NULL)
   {
      Print("⛔ CRÍTICO: No se creó el objeto estrategia.");
      return INIT_FAILED;
   }

   // Inicializamos la estrategia (Carga de indicadores, etc.)
   if (!objetoEstrategia.Init())
   {
      Print("⛔ CRÍTICO: Falló la inicialización (Init) de la estrategia.");
      delete objetoEstrategia;
      return INIT_FAILED;
   }

   if (RiskPercent <= 0)
   {
      Print("⛔ ERROR: Riesgo <= 0");
      return INIT_PARAMETERS_INCORRECT;
   }

   // Iniciamos el Timer (cada 1 segundo) para actualizaciones visuales
   EventSetTimer(1);

   Print("✅ Framework POO v14.40 (TFM Refactored) Cargado. Estrategia: ", EnumToString(Estrategia));
   return (INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| ON DEINIT                                                        |
//| Se ejecuta al quitar el EA o cambiar parámetros                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   EventKillTimer();

   // GARBAGE COLLECTOR MANUAL
   // Destruimos la estrategia para liberar memoria y limpiar gráficos
   if (objetoEstrategia != NULL)
   {
      delete objetoEstrategia;
      objetoEstrategia = NULL;
   }

   // Limpiamos paneles y líneas dibujadas por el EA
   CVisuals::Limpiar();
}

//+------------------------------------------------------------------+
//| ON TIMER                                                         |
//| Se ejecuta cada segundo. Ideal para tareas visuales.             |
//+------------------------------------------------------------------+
void OnTimer()
{
   if (MostrarPanel)
   {
      // Chequeo rápido de horario solo para informar en el panel
      bool horarioOK = true;
      if (UsarHorario)
      {
         bool hOK = (CTime::EsHoraOperativa(HoraInicio_1, MinInicio_1, HoraFin_1, MinFin_1) ||
                     CTime::EsHoraOperativa(HoraInicio_2, MinInicio_2, HoraFin_2, MinFin_2));
         bool dOK = CTime::EsDiaOperativo(OpLunes, OpMartes, OpMiercoles, OpJueves, OpViernes, OpFinde);
         horarioOK = (hOK && dOK);
      }

      // 1. Actualizamos Texto del Panel
      CVisuals::ActualizarPanel(EnumToString(Estrategia), horarioOK, ContarMisPosiciones(), MagicNumber);

      // 2. Dibujamos Líneas de Operaciones (Entrada, SL, TP) - Estilo TradingView Dark
      CVisuals::DibujarInfoOperaciones(MagicNumber);

      // 3. Dibujamos Indicadores de la Estrategia (si tiene lógica visual)
      // Delegamos al objeto activo (TFM, Combo, RSI, etc.)
      if (objetoEstrategia != NULL)
         objetoEstrategia.OnTimerVisuals();

      ChartRedraw();
   }
}

//+------------------------------------------------------------------+
//| HELPER: Detectar Nueva Vela                                      |
//+------------------------------------------------------------------+
bool IsNewBar()
{
   datetime currentBarTime = iTime(Symbol(), Period(), 0);
   if (lastBarTime != currentBarTime)
   {
      lastBarTime = currentBarTime;
      return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| HELPER: Contar Posiciones Propias                                |
//+------------------------------------------------------------------+
int ContarMisPosiciones()
{
   int count = 0;
   int total = PositionsTotal();
   for (int i = 0; i < total; i++)
   {
      ulong ticket = PositionGetTicket(i);
      if (ticket > 0)
      {
         // Filtramos por MagicNumber y Símbolo para no contar operaciones ajenas
         if (PositionGetInteger(POSITION_MAGIC) == MagicNumber &&
             PositionGetString(POSITION_SYMBOL) == Symbol())
         {
            count++;
         }
      }
   }
   return count;
}

//+------------------------------------------------------------------+
//| HELPER: Verificar Rollover                                       |
//+------------------------------------------------------------------+
bool EsHoraRollover()
{
   MqlDateTime dt;
   TimeCurrent(dt);
   // Rollover típico 23:55 - 00:05 (Horario donde el spread se dispara)
   if (dt.hour == 23 && dt.min >= 55)
      return true;
   if (dt.hour == 0 && dt.min < 5)
      return true;
   return false;
}

//+------------------------------------------------------------------+
//| HELPER: Verificar Estado del Sistema                             |
//+------------------------------------------------------------------+
bool CheckSystemReady()
{
   if (!TerminalInfoInteger(TERMINAL_CONNECTED))
      return false;
   if (!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED))
      return false;
   ENUM_SYMBOL_TRADE_MODE tradeMode = (ENUM_SYMBOL_TRADE_MODE)SymbolInfoInteger(Symbol(), SYMBOL_TRADE_MODE);
   if (tradeMode != SYMBOL_TRADE_MODE_FULL)
      return false;
   if (Bars(Symbol(), Period()) < 100)
      return false; // Necesitamos historial para calcular indicadores
   if (IsStopped())
      return false;

   double bid = SymbolInfoDouble(Symbol(), SYMBOL_BID);
   double ask = SymbolInfoDouble(Symbol(), SYMBOL_ASK);
   if (bid <= 0 || ask <= 0)
      return false;

   return true;
}

//+------------------------------------------------------------------+
//| ON TICK                                                          |
//| El corazón del robot. Se ejecuta con cada cambio de precio.      |
//+------------------------------------------------------------------+
void OnTick()
{
   // Chequeos básicos de salud del sistema
   if (!CheckSystemReady())
      return;
   if (objetoEstrategia == NULL)
      return;

   // ---------------------------------------------------------
   // 1. DEFENSA (Gestión de Trades Abiertos)
   // ---------------------------------------------------------
   // Si tenemos posiciones, gestionamos BreakEven, Trailing Stop, TTL, etc.
   if (ContarMisPosiciones() > 0)
   {
      CTradeMgmt::Gestionar(trade, MagicNumber, UsarBreakEven, BE_Trigger_Pts, BE_Offset_Pts, BreakEvenReal, UsarTrailing, TS_Distancia_Pts, TS_Step_Pts, MaxVelasTTL);
   }

   // ---------------------------------------------------------
   // 2. ATAQUE (Búsqueda de Entradas)
   // ---------------------------------------------------------
   // Solo analizamos el mercado cuando cierra una vela (para evitar ruido intra-vela)
   if (!IsNewBar())
      return;

   // --- Filtros Operativos ---
   bool operativaPermitida = true;

   // A. Filtro Horario
   if (UsarHorario)
   {
      bool hOK = (CTime::EsHoraOperativa(HoraInicio_1, MinInicio_1, HoraFin_1, MinFin_1) ||
                  CTime::EsHoraOperativa(HoraInicio_2, MinInicio_2, HoraFin_2, MinFin_2));
      bool dOK = CTime::EsDiaOperativo(OpLunes, OpMartes, OpMiercoles, OpJueves, OpViernes, OpFinde);
      if (!hOK || !dOK)
         operativaPermitida = false;
   }

   // B. Filtro Rollover (Spreads altos)
   if (EvitarRollover && CTime::EsRollover(EvitarRollover))
      operativaPermitida = false;

   // Si hay filtro activo o ya tenemos posición, no buscamos entrada
   if (!operativaPermitida)
      return;
   if (ContarMisPosiciones() > 0)
      return;

   // C. Filtro Spread (Protección final)
   if (!CExecution::CheckSpread(MaxSpreadPoints))
      return;

   // ---------------------------------------------------------
   // 3. SEÑAL (Consultar al Estratega)
   // ---------------------------------------------------------
   // Polimorfismo puro: No importa qué estrategia sea, todas responden a "ObtenerSenal"
   int direccion = objetoEstrategia.ObtenerSenal();

   if (direccion == 0)
      return; // Sin señal (Ruido o espera)

   // ---------------------------------------------------------
   // 4. EJECUCIÓN (Disparar la Orden)
   // ---------------------------------------------------------
   double precioEntrada = (direccion == 1) ? SymbolInfoDouble(Symbol(), SYMBOL_ASK) : SymbolInfoDouble(Symbol(), SYMBOL_BID);
   double slPrecio = 0.0;

   // --- CÁLCULO DE STOP LOSS (Híbrido) ---
   if (UsarSL_Estructural)
   {
      // Opción A: Pivotes (High/Low reciente) - Se adapta a la volatilidad
      slPrecio = CRisk::GetPivotSL(direccion, Pivot_Periodo, Pivot_Padding);
   }
   else
   {
      // Opción B: Puntos Fijos - Estático
      slPrecio = CRisk::CalcularSL_Fijo(direccion, precioEntrada, SL_PuntosFijos);
   }

   // Seguridad: Si el cálculo falló (ej: array vacío), abortamos para no operar sin SL
   if (slPrecio == 0.0)
      return;

   // --- CÁLCULO DE LOTAJE (Money Management) ---
   // Calculamos el riesgo monetario basado en la distancia REAL al SL
   double lotaje = CRisk::CalcularLotaje(precioEntrada, slPrecio, RiskPercent);

   if (lotaje > 0)
   {
      // Chequeo final de margen (¿Tengo dinero suficiente?)
      if (CExecution::CheckMargin(direccion, lotaje, precioEntrada))
      {
         // Calculamos TP basado en Ratio R:R (ej: 1:2)
         double tpPrecio = CRisk::CalcularTP(direccion, precioEntrada, slPrecio, RewardRatio);

         // Enviar Orden al Broker
         CExecution::EnviarOrden(trade, direccion, lotaje, slPrecio, tpPrecio, ComentarioOrden);
      }
   }
}