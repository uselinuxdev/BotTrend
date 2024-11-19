
//+------------------------------------------------------------------+
//|                                                     BotTrend.mq5 |
//|                                    Copyright 2020, Usefilm Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2020, Usefilm Corp."
#property link      "https://www.mql5.com"
#define VERSION "8.25"
#property version VERSION

// InclusiÃ³n de objetos de liberia estandar
#include<Trade\Trade.mqh>
#include <Trade\SymbolInfo.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\AccountInfo.mqh>
#include "PanelBotTrend.mqh"
CTrade cTrade;
CSymbolInfo SymbolInfo;
CPositionInfo cPos;
CAccountInfo Cacc;
CAppDialog AppPanel;

//--- input parameters
enum ENUM_FRANCISCA
{
   SIN_FRANCISCA,
   FRANCISCA_10,
   FRANCISCA_20
};

enum ENUM_BOTMODE
{
   WORKING_DAY,
   SOFT_FRIDAY,
   SOFT_USER,
   SUMMER_TIME,
   CHRISTMAS,
   ZERO_GRAVITY,
   OPEN_MARKET
};

enum ENUM_THREAD
{
   MAXPARM,
   ISFRIDAY,
   FOUNDS
};

enum ENUM_LICENCE
{
   GOLD,
   SILVER
};

enum ENUM_CENT
{
   CENT_1,
   CENT_10,
   CENT_20,
   CENT_50,
   CENT_100
};


enum ENUM_ZGRAVITY
{
   NO_ZGRAVITY,
   STEP_3,
   STEP_4,
   STEP_5,
   STEP_6
};

// CONTROL POR TIEMPO
datetime timeCurent;
datetime timeCheck;

//--- Global vars
//+------------------------------------------------------------------+
//| Expert MAGIC number                                              |
//+------------------------------------------------------------------+
#define MAGICTREND 13330
string BOTNAME="TRENDBOT "+VERSION;
long ATRENDBOT[9];
ulong ATREND[9][99];
// Cerrar hilo en ganancias dejar op mayor.
double dLOTBULL[9];
double dLOTBear[9];
// Arrays con los precios max/min por cada hilo
double dHPRICE[9];
double dLPRICE[9];
double dZeroPRICE[9]; // <--- Nivel +1TP ZeroBull -1TP ZeroBear. 8.25 VER
/////////////////////////////  <-- SUSTITUIR
double ATRENDPROFIT[9];
// Salvar el step de todos los hilos
string ACOMMENT[9];
MqlRates rCurrent[];
double dSupport,dResistance;
string vtext;
enum ENUM_TIPOTEXT{MSGBOX,ALERT,COMMENT,PRINT};
ENUM_TIPOTEXT ENUMTXT;
// FRANCICA
input ENUM_FRANCISCA enumfrancisca=FRANCISCA_10;
ENUM_BOTMODE enumbotmode=WORKING_DAY;
ENUM_THREAD enumthread=MAXPARM;
ENUM_LICENCE enumlicence=GOLD;
double pips;
int iFrancisca=10;
int iCent=1;
int piNumBars=3;
input ENUM_TIMEFRAMES botperiod=PERIOD_M5;
input double   TakeProfit=60;
// input double   dComisionLot= 2.75; // IC MARKETS
input double   dComisionLot=2;
int iComisionPips=0;
input int      iExitProfitStep=2;
input int      iMaxThead=1;
input bool     bSoftFriday=true;
input bool     bHollidays=true;

input ENUM_CENT ENUMCENT=CENT_1;
input datetime dWaitBreakZero;
bool bOpenMarket=true;
input ENUM_ZGRAVITY EZGRAVITY=STEP_3;
input short shourclose=16;


// Dont open when the market will be to close. Or opened 1h.
int iHilos=0;
double dLotBear=0.0;
double dLotBULL=0.0;
double dCommision=0.0;
double dSwapAll=0.0;
ENUM_POSITION_TYPE ENUMBARDIR;
double Lots = 0.01;
int lotdecimal = 2; 
//+------------------------------------------------------------------+
//| Control de licencias                                             |
//+------------------------------------------------------------------+
long ALOGINGOLD[];
long ALOGINSILVER[];
MqlDateTime MQDATELOGIN[];
//+------------------------------------------------------------------+
//| End control de licencias                                         |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//---
   // Check point symbol
   double ticksize=SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_SIZE);
   pips=ticksize;
   timeCheck=TimeCurrent()+75;
   // INIT ARRAY DE PROFIT
   ArrayInitialize(ATRENDPROFIT,0);
   // INIT array de contador de STEP
   countbot(); 
   // Coger niveles diarios.
   GetLevels();
   // Reload ACOMMENT array
   LoadAcomment();
   // Licence code
   LoadLicenceAccount();
   // Primer check de licences
   if(CheckLicence()==0) return -1;
   //--- create application dialog. Si falla da igual, continuar
   if(ExtDialog.Create(0,"BotTrend Panel version: "+VERSION,0,40,40,450,260))
   {
      //--- run application
      ExtDialog.Run();
   }
//---
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---
   //--- destroy dialog
   ExtDialog.Destroy(reason);
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
//---   // Check period with input value
   timeCurent = TimeCurrent();
   if(Period()!= botperiod)
   {
         vtext="El perido es diferente al seleccionado en el robot : "+EnumToString(botperiod)+"!="+EnumToString(Period())+". Robot parado durante 30 segundos.";
         ENUMTXT = ALERT;
         expertLog();
         // Wait 30 secon
         Sleep(30000);
         return;
   }
   // SÃ³lo refrescar 1 vez lo Rates por Tick
   // Coger Ãºltimas barras
   GetLastBars();
   // Contar ops.
   if(countbot()<0) return;
   // Every ticks Check Franciscada
   if(goFrancisca()<0) return;
   // Comprobar hilo en beneficios PRD code
   /////////////////if(CheckAllThreadProfit()<0) return;   
   //// Check for new steps // EN PROD PONER CADA TICK
   if(CheckNewStep()<0) return;
   // Igualar hilo G 0
   if(EqualZero()<0) return;
   /// Comprobar rotura de soportes si los hilos estÃ¡n en gravedad 0
   if(CheckBreakDayLevel()<0) return;
   // Comprobar cada 1min.
   if(timeCheck<timeCurent)
   {
      // Next minute
      timeCheck = TimeCurrent()+60;
      // Ajustar cent
      GetCent();
      // Contar ops.
      if(countbot()<0) return;
      // 8.25 funtion. Upload prices limits every minute
      if(UpdateThreadPrices()<0) return;
      // Comprobar hilo en beneficios TEST code
      if(CheckAllThreadProfit()<0) return;
      // Abrir cada minuto
      if((MarketClosing()!=0) && (BotVacation()!=0))
      {
         if(CheckForOpen()<0) return;
      }
   }
   // BreakEvent en posiciones laterales iguales
   //--- go trading only for first ticks of new bar. Actual bar is the last array element
   // rCurrent tiene las barras definidas en parametro. Ultimo de array barra actual.
   if(rCurrent[piNumBars-1].tick_volume<5)
   { 
      // Contar ops.
      if(countbot()<0) return;
      // Coger niveles diarios plus operaciones. 
      // Cada 5 minuto para dar tiempo a q la barra actual se defina.
      if(GetLevels()<0) return;
      // Niveles G0. SL and TP G-1 (3 operations)
      if(SetLevelZero()<0) return;
      // Actualiza panel 
      RefressPanel();
   }
  }
//+------------------------------------------------------------------+

// ------------------------------------------------------------------------------------------------------------------- //
//                                                BILLING CODE                                                         //
// ------------------------------------------------------------------------------------------------------------------- //
void LoadLicenceAccount()
{
   ArrayResize(ALOGINGOLD,25);
   ArrayFill(ALOGINGOLD,0,25,0);
   // Creator accounts
   ALOGINGOLD[0]=211681; // DOLO
   ALOGINGOLD[1]=67059701;    /// ROBOFOREX
   ALOGINGOLD[2]=9290;    /// DEMO FUSION
   // Client accounts
   // USE VANTAGE LIVE & DEMO
   ALOGINGOLD[3]=205996;
   ALOGINGOLD[4]=0;  // LIBRE
   // Miguel Demo Vantage
   ALOGINGOLD[5]=781025;
   // Cuenta Carlos Sastre IC Gold 1
   ALOGINGOLD[6]=206400;
   // Angela Recio (Carlos Sastre)
   ALOGINGOLD[7]=206969;
   // Gaiton REAL
   ALOGINGOLD[8]=7023169;
   // Use ROBOFOREX
   ALOGINGOLD[9]=67013738;
     
   /////////////////////////////////////////////////////////////////////////////////////////
   // Silver licences. PosiciÃ³n igual NÂº de cuenta y fecha
   ArrayResize(ALOGINSILVER,25);
   ArrayFill(ALOGINSILVER,0,25,0);
   ArrayResize(MQDATELOGIN,25);
   // Cuenta Carlos (IC Copy a mt4)
   ALOGINSILVER[0]=50427567; 
   // Fecha fin Carlos
   MQDATELOGIN[0].day=12;
   MQDATELOGIN[0].mon=12;
   MQDATELOGIN[0].year=2020;
   // Cuenta Carlos Roboforex
   ALOGINSILVER[1]=7809183; 
   // Fecha fin Carlos
   MQDATELOGIN[1].day=27;
   MQDATELOGIN[1].mon=2;
   MQDATELOGIN[1].year=2022;
   // Mick G. Johnson
   ALOGINSILVER[4]=1139912;
   MQDATELOGIN[4].day=08;
   MQDATELOGIN[4].mon=05;
   MQDATELOGIN[4].year=2021;
   // Juan (Carlos Norte)
   ALOGINSILVER[5]=7803938;
   MQDATELOGIN[5].day=03;
   MQDATELOGIN[5].mon=07;
   MQDATELOGIN[5].year=2021;         
}
short CheckLicence()
{
   // Get actual account
   long laccount;
   laccount=Cacc.Login();
   // Check Gold licences
   
   for(int i=0;i<ArrayRange(ALOGINGOLD,0);i++)
   {
      if(ALOGINGOLD[i]==laccount)
      {
         vtext="Bot ha encontrado una licencia Gold para la cuenta:"+IntegerToString(laccount)+" - "+Cacc.Name();
         ENUMTXT = PRINT;
         expertLog();
         enumlicence=GOLD;
         return 1;
      }
   }
   // Buscar licencia por suscripciÃ³n
   for(int i=0;i<ArrayRange(ALOGINSILVER,0);i++)
   {
      if(ALOGINSILVER[i]==laccount)
      {
         vtext="Bot ha encontrado una licencia Silver para la cuenta:"+IntegerToString(laccount)+" - "+Cacc.Name();
         ENUMTXT = PRINT;
         expertLog();
         printf("Licencia vÃ¡lida hasta el %02d/%02d/%4d",MQDATELOGIN[i].day,MQDATELOGIN[i].mon,MQDATELOGIN[i].year,".");
         enumlicence=SILVER;
         return 1;
      }
   }   
   vtext="La cuenta "+IntegerToString(laccount)+" no se encuentra licenciada.Ãltimo aviso, PAGA LA DROGA!";
   ENUMTXT = PRINT;
   expertLog();
   return 0;
}

short CheckSilverEnd()
{
   long laccount;
   datetime dNow=TimeCurrent();
   MqlDateTime strdate;
   TimeToStruct(dNow,strdate);
   // Si la licencia no es silver return 1
   if(enumlicence!=SILVER) return 1;
      // Get actual account
   laccount=Cacc.Login();
   // Buscar licencia por suscripciÃ³n
   for(int i=0;i<ArrayRange(ALOGINSILVER,0);i++)
   {
      if(ALOGINSILVER[i]==laccount)
      {
         // PosiciÃ³n de cuenta en i
         if(MQDATELOGIN[i].year<=strdate.year && MQDATELOGIN[i].mon<=strdate.mon && MQDATELOGIN[i].day<strdate.day)
         {
            vtext="La cuenta "+IntegerToString(laccount)+" ha finalizado su perido de suscripciÃ³n.Renueve su licencia!!!.";
            ENUMTXT = PRINT;
            expertLog();
            printf("La licencia finalizÃ³ el %02d/%02d/%4d",MQDATELOGIN[i].day,MQDATELOGIN[i].mon,MQDATELOGIN[i].year,".");
            return 0;
         }
         // La licencia poner el Ãºltimo dÃ­a vÃ¡lido
         if(MQDATELOGIN[i].year==strdate.year && MQDATELOGIN[i].mon==strdate.mon && MQDATELOGIN[i].day+7>strdate.day)
         {
            vtext="La cuenta "+IntegerToString(laccount)+" finaliza su suscripciÃ³n en menos de 7 dÃ­as.";
            ENUMTXT = PRINT;
            expertLog();
            printf("La licencia finalizarÃ¡ el %02d/%02d/%4d",MQDATELOGIN[i].day,MQDATELOGIN[i].mon,MQDATELOGIN[i].year,".");
            return 1;
         }
         // Licencia encontrada y correcta
         return 1;
      }
   } 
   // Bien
   return 0;
}

// ------------------------------------------------------------------------------------------------------------------- //
//                                                BILLING CODE END                                                     //
// ------------------------------------------------------------------------------------------------------------------- //


// FUNTION BOT SECTION
void expertLog()
{
   switch(ENUMTXT){
      case MSGBOX:MessageBox(vtext);break;
      case ALERT:Alert(vtext);break;
      case COMMENT:Comment(vtext);break;
      case PRINT:Print(vtext);break;
   }
}  

void GetLastBars()
{
   SymbolInfo.Name(_Symbol);
   SymbolInfo.Refresh();
   SymbolInfo.RefreshRates();
   
   // Barra actual rCurrent[piNumBars-1]
   int copied=CopyRates(Symbol(),0,0,piNumBars,rCurrent); 
   if(copied<1)
   {
      vtext="El copiado de datos historicos de "+_Symbol+" ha fallado, historial no disponible.";
      ENUMTXT = ALERT;
      expertLog();
      return;
   }
}

// ------------------------------------------------------------------------------------------------------------------- //
//                                                PRICE THREAD FUNTIONS                                                //
// ------------------------------------------------------------------------------------------------------------------- //
// Esta función carga el edge de cada hilo. Si está en positivo actualiza valor en esa dirección.
short UpdateThreadPrices()
{
   // Recorrer hilos y cargar la última
   ulong cticket=0;
   for(int i=0;i<9;i++)
   {
      for(int x=0;x<99;x++)
      {
         if(ATREND[i][x]<=0) continue;
         if(ATREND[i][x]>cticket) cticket=ATREND[i][x];
      }
      // on this point we have the edge ticket
      if(cticket>0)
      {
         return UpdatePrices(i,cticket);
      }
   }
   return 1;
}

short UpdatePrices(int ithread,ulong lTicketEdge)
{
   MqlRates rThreadBars[];
   ENUM_POSITION_TYPE TYPE_POS;
   datetime dopen;
   datetime dNow;
   long lmagic;
   // Cargar la posición
   if(!cPos.SelectByTicket(lTicketEdge))
   {
      vtext="UpdatePrices: No se ha podido cargar el ticket"+IntegerToString(lTicketEdge);
      ENUMTXT = PRINT;
      expertLog(); 
      return -1;
   }
   // Only update if a valid edge op with profit.
   if(cPos.Profit()<0) return 0;
   TYPE_POS=cPos.PositionType();
   lmagic=cPos.Magic();
   if (_Symbol!=cPos.Symbol() || (IsMyMagic(lmagic)<0)) return 0;
   dopen=cPos.Time();
   dNow=TimeCurrent();
   // Check all bars since open edge
   int copied=CopyRates(Symbol(),PERIOD_M5,dopen,dNow,rThreadBars);
   if(copied<2)
   {
      // Cargar barra actual
      copied=CopyRates(Symbol(),PERIOD_M5,0,1,rThreadBars);
   }
   // INIT VALUES
   // Recorrer las barras, menos la actual
   for(int i=0;i<copied-1;i++)
   { 
      if((TYPE_POS==POSITION_TYPE_SELL) && (dLPRICE[ithread]>rThreadBars[i].low)) 
      {
         dLPRICE[ithread]=rThreadBars[i].low;
         vtext="UpdatePrices: Actualizado precio Bear:"+DoubleToString(dLPRICE[ithread]);
         ENUMTXT = PRINT;
         expertLog(); 
      }
      if((TYPE_POS==POSITION_TYPE_BUY) && (dHPRICE[ithread]<rThreadBars[i].high)) 
      {
         dHPRICE[ithread]=rThreadBars[i].high;
         vtext="UpdatePrices: Actualizado precio Bull:"+DoubleToString(dHPRICE[ithread]);
         ENUMTXT = PRINT;
         expertLog(); 
      }
   }
   // Bien
   return 1;
}

// La funciÃ³n se llama con el ticket mÃ¡s antiguo del hilo y se cargan los min/max prices desde esa apertura
double GetBarPiecesThread(datetime doldopen,ENUM_POSITION_TYPE TYPE_POS)
{
   MqlRates rThreadBars[];
   datetime dNow;
   double dLowPrice;
   double dHighPrice;
   double dNextScalp=0;
   SymbolInfo.Name(_Symbol);
   SymbolInfo.Refresh();
   SymbolInfo.RefreshRates();
   dNow=TimeCurrent();
   int copied=CopyRates(Symbol(),PERIOD_M5,doldopen,dNow,rThreadBars);
   if(copied<2)
   {
      // Cargar barra actual
      copied=CopyRates(Symbol(),PERIOD_M5,0,1,rThreadBars);
   }
   // INIT VALUES
   dLowPrice=rThreadBars[0].low;
   dHighPrice=rThreadBars[0].high;
   // Recorrer las barras, menos la actual
   for(int i=0;i<copied-2;i++)
   { 
      if(rThreadBars[i].low<dLowPrice) dLowPrice=rThreadBars[i].low; 
      if(rThreadBars[i].high>dHighPrice) dHighPrice=rThreadBars[i].high; 
   }
   // Return the oposit price than operation type need to be checking.If the price is lower/upper history candies + 1Francisca
   if(TYPE_POS==POSITION_TYPE_SELL)
   {
      dNextScalp = dHighPrice + (iFrancisca*pips);
   }
   else
   {
      dNextScalp = dLowPrice - (iFrancisca*pips);
   }
   // Bien
   return dNextScalp;
}

// ------------------------------------------------------------------------------------------------------------------- //
//                                              PRICE THREAD FUNTIONS END                                              //
// ------------------------------------------------------------------------------------------------------------------- //


// Conger el soporte / resistencia diario por barras de hora
// Se incluyen las operaciones activas
short GetLevels()
{
   MqlRates rLastBars[];
   ulong ticket=0;
   ulong lmagic=0;
   // Hacerlo con 5min (12(60/5) * 24h)
   //int iPeriodos=24;
   int iPeriodos=288;
   double dPriceOp=0;
   SymbolInfo.Name(_Symbol);
   SymbolInfo.Refresh();
   SymbolInfo.RefreshRates();
   int copied=CopyRates(Symbol(),PERIOD_M5,0,iPeriodos,rLastBars);
   if(copied<iPeriodos)
   {
      vtext="GetLevels: No se ha podido cargar las barras de las últimas 24h.";
      ENUMTXT = PRINT;
      expertLog(); 
      return -1;
   }
   // Reset values
   dSupport=rLastBars[0].low;
   dResistance=rLastBars[0].high;
   // Recorrer array
   for(int i=0;i<copied;i++)
   { 
      if(rLastBars[i].low<dSupport) dSupport=rLastBars[i].low; 
      if(rLastBars[i].high>dResistance) dResistance=rLastBars[i].high; 
   }
   //// TEST sÃ³lo limites diarios
  ////////////// return 1;
   // Ahora comprobaremos el mÃ¡x y mÃ­nimo de las operaciones
   for(int i=0;i<PositionsTotal();i++) // returns the number of current positions
   {
      if(!cPos.SelectByIndex(i))
      {
         Print("Error al seleccionar orden. Error = ",GetLastError());
         return -1;
      }
      if(_Symbol!=cPos.Symbol()) continue; 
      
      // Check Bot
      lmagic=cPos.Magic();
      if(IsMyMagic(lmagic))
      {
         ticket=cPos.Ticket();
         dPriceOp=cPos.PriceOpen();
         // Seleccionar deal
         if(cPos.PositionType()==POSITION_TYPE_SELL)
         {
            if(dPriceOp<dSupport) dSupport=dPriceOp; 
         }
         else
         {
            if(dPriceOp>dResistance) dResistance=dPriceOp;
         }
      }
   } 
   // Bien
   return 1;
}

// Retorna true si es alguna hora de apertura de mercados
bool CheckOpenMarket()
{
   ulong lstep=0;
   datetime dAhora=TimeCurrent();
   MqlDateTime strdate;
   TimeToStruct(dAhora,strdate);
   // Session	Major Market	Hours (GMT)
   // -----------------------------------------------
   // // European Session	London	9:00 GMT (Lock 30 min till it)
   if((strdate.hour==8 && strdate.min > 30 ) || (strdate.hour==9 && strdate.min < 2))
   {
      if(bOpenMarket==true)
      {
         vtext="Desactivada creaciÃ³n G1 en apertura Londres.";
         ENUMTXT = PRINT;
         expertLog();
      }
      bOpenMarket=false;
      return bOpenMarket;
   }
   // // North American Session	New York	Wall Street 15:30 GMT (Lock 30 min till it)
   if(strdate.hour==15 && strdate.min < 31 )
   {
      if(bOpenMarket==true)
      {
         vtext="Desactivada creaciÃ³n G1 en apertura Wall Street.";
         ENUMTXT = PRINT;
         expertLog();
      }
       bOpenMarket=false;
       return bOpenMarket;
   }
   bOpenMarket=true;   
   return bOpenMarket;
}

// Hasta GZero se duplica luego aÃ±adir un Lots por step
double GetLotStep(ulong lstep)
{
   double dLot=0.00;
   ulong sZgravity;
   // Coger el parÃ¡metro que ha seleccionado el usuario
   sZgravity=GetGravityStep();
   dLot=Lots*iCent;
   for(ulong i=1;i<sZgravity;i++)
   {
      dLot=(dLot*2)+(Lots*iCent);
   }
   // Bien
   return NormalizeDouble(dLot,lotdecimal);
}

// La funcion retorna si el NÂº mÃ¡gico es de los del bot.2 Si es un TBOT
short IsMyMagic(long lMagicCheck)
{
   vtext = "Check NÂº magico:"+IntegerToString(lMagicCheck);
   ENUMTXT = PRINT;
   //expertLog();
   if(lMagicCheck >=MAGICTREND && lMagicCheck<=MAGICTREND+9) return 1;
   // No es de los nuestros
   return 0;
}

// FunciÃ³n de actualizaciÃ³n de datos del panel
void RefressPanel()
{
  ExtDialog.UpdatePannel(EnumToString(enumbotmode),dLotBULL,dLotBear,iHilos,EnumToString(enumthread),dCommision,dSwapAll);
}


void checkBardir()
{
   // Declarations and rest values.
   ENUMBARDIR = WRONG_VALUE;
   ENUMTXT = PRINT;
   vtext="";

   //vtext = "Comprobando tendencia de los Ãºltimos "+IntegerToString(piNumBars)+" periodos.";
   //expertLog();
   // Recorrer las Nvelas desde la posicion anterior a la actual 0
   //rCurrent[piNumBars-1].close Precio actual en barra en curso
   if(rCurrent[piNumBars-1].close < rCurrent[0].open)
   {
      vtext = "Detectada tendencia BEAR (SELL).Usando tendecia.";
      ENUMBARDIR = POSITION_TYPE_SELL;
   }
   else
   {
      vtext = "Detectada tendencia BULL (BUY).Usando tendecia.";
      ENUMBARDIR = POSITION_TYPE_BUY;
   }
  // Print check result
  // expertLog();  
}

/// CÃ¡lculo comisiÃ³n por lote. De las posiciÃ³n cargada. El importe es negativo
double getComisionPos()
{
   double dComm=0;
   dComm=NormalizeDouble(cPos.Volume()*(dComisionLot*2),Digits());
   dComm=dComm*(-1);
   //Calculo de comisiones en pips
   iComisionPips=int(dComisionLot*2);
   return dComm;
}


void GetCent()
{
   // CENT MODE
   //Asignar CentMode
   switch(ENUMCENT)
   {
      case CENT_1:
         iCent=1;
         break;
      case CENT_10:
         iCent=10;
         break;
      case CENT_20:
         iCent=20;
         break;
      case CENT_50:
         iCent=50;
         break;
      case CENT_100:
         iCent=100;
         break;
   }
}

// NuevaMisiÃ³n para la operaciÃ³n en memoria
// Si hay que actualizar TP cuando se ha cerrado hilo en ganancias
// Llamada desde closethisthread y Breakdown
double NewMision(ulong lTicket)
{
   double dprice=0.00;
   double DSL=0.00;
   double dNewTP=0.00;
   ENUM_POSITION_TYPE TYPE_POS=WRONG_VALUE; 
   // Cargar la posiciÃ³n
   if(!cPos.SelectByTicket(lTicket))
   {
      Print("Error al seleccionar orden"+IntegerToString(lTicket)+". Error = ",GetLastError());
      return -1;
   }
   TYPE_POS=cPos.PositionType();
   dprice=cPos.PriceCurrent();
   if(TYPE_POS==POSITION_TYPE_SELL)
   {
      DSL=dprice+((iFrancisca)*pips);
      dNewTP=dprice-(TakeProfit*pips);
   }
   else
   {
      DSL=dprice-((iFrancisca)*pips);
      dNewTP=dprice+(TakeProfit*pips);
   }
   
   if(!cTrade.PositionModify(lTicket,DSL,dNewTP))
   {
      vtext="Error en funciÃ³n NewMision al actualizar niveles en ticket "+IntegerToString(lTicket)+" error:"+IntegerToString(GetLastError());
      ENUMTXT = PRINT;
      expertLog();
      return -1;
   }
   // Bien
   return 1;
}

/////////////////////////////////////////////// Contar bots. MAX 9 hilos
short countbot()
{
   int ipos=0; 
   ulong lmagic=0;
   double dTP=0;
   bool bSLProfit=false;
   // La funcion cuenta los bot que estan abiertos actualmente. Resetea el array con 0 
   ///////////////////ArrayResize(ATRENDBOT,9);
   ArrayFill(ATRENDBOT,0,9,0);
   // Nuevo array HILO, VALOR
   ArrayInitialize(ATREND,0);
   ArrayInitialize(dLOTBULL,0);
   ArrayInitialize(dLOTBear,0);
   // Valores panel
   dLotBear=0.0;
   dLotBULL=0.0;
   dCommision=0.0;
   dSwapAll=0.0;
   
   ulong ticket=0;
   for(int i=0;i<PositionsTotal();i++) // returns the number of current positions
   {
      if(!cPos.SelectByIndex(i))
      {
         Print("Error al seleccionar orden. Error = ",GetLastError());
         return -1;
      }
      if(_Symbol!=cPos.Symbol()) continue; 
      
      // Check Bot
      lmagic=cPos.Magic();
      if(IsMyMagic(lmagic))
      {
         ticket=cPos.Ticket();
         bSLProfit=bCheckSlProfit();
         dTP=cPos.TakeProfit();
         // Seleccionar deal
         ipos=(int)(lmagic-MAGICTREND);
         ATRENDBOT[ipos]=(int)lmagic;
         // Calculo de comisiÃ³n: TamaÃ±o del lote * Importe de la comisiÃ³n * 2(Apertura y cierre).
         dCommision+=getComisionPos();
         dSwapAll+=cPos.Swap();
         if(cPos.PositionType()==POSITION_TYPE_SELL)
         {
            dLotBear+=cPos.Volume();
            // Si la operaciÃ³n estÃ¡ salvada por iFrancica. No contarla para los lotajes del hilo
            if(bSLProfit && dTP>0) continue;
            dLOTBear[ipos]+=cPos.Volume();
         }
         else
         {
            dLotBULL+=cPos.Volume();
            // Si la operaciÃ³n estÃ¡ salvada por iFrancica. No contarla para los lotajes del hilo
            if(bSLProfit && dTP>0) continue;
            dLOTBULL[ipos]+=cPos.Volume();
         }
         // El proceso siempre retorna el array de menor a mayor ticket
         for(int x=0;x<99;x++)
         {
            // Control si encuentra parar.
            if(ATREND[ipos][x]==0)
            {
               ATREND[ipos][x]=ticket;
               x=99;
            }
         }
      }
   }
   /////////////////////////////////////
   return 1;
}

/// Retorna el cÃ³digo de hilo por la fecha inicial
string GetTCode()
{
   string scode="";
   scode=DoubleToString(Cacc.Equity(),2);
   return scode;
}

/// Load comment array.
/// La funiÃ³n es llamada en la apertura del bot para escanear las operaciones abiertas previamente por el bot
short LoadAcomment()
{
   ulong ticket=0;
   int ipos=0;
   ulong lmagic=0;
   string scomment="";
   for(int i=0;i<PositionsTotal();i++) // returns the number of current positions
   {
      if(!cPos.SelectByIndex(i))
      {
         Print("Error al seleccionar orden. Error = ",GetLastError());
         return -1;
      }
      if(_Symbol!=cPos.Symbol()) continue; 
      
      // Check Bot
      lmagic=cPos.Magic();
      if(IsMyMagic(lmagic))
      {
         // Seleccionar deal
         ipos=(int)(lmagic-MAGICTREND);
         scomment=cPos.Comment();
         ACOMMENT[ipos]=scomment;
         if(StringLen(scomment)<=0)
         {
            // COMENTARIO MAX 32 CHAR
            scomment=GetTCode();
            scomment=BOTNAME+" ("+scomment+") : 4";
            ACOMMENT[ipos]=scomment;
         }
      }
   }
   // Bien
   return 1;
}


// Check if SL are on profit to dont sell again
bool bCheckSlProfit()
{
   bool bprofit=false;
   double dOpen=0;
   double dSL=0;
   ENUM_POSITION_TYPE TYPE_POS;
   // Get values
   TYPE_POS=cPos.PositionType();
   dOpen=cPos.PriceOpen();
   dSL=cPos.StopLoss();
   // Si no tiene SL retornar 0
   if(dSL<=0) return bprofit; 
   // Control pos Bear
   if(TYPE_POS==POSITION_TYPE_SELL)
   {
      if(dSL<dOpen) bprofit=true;  
   }
   else
   {
      // POS TIPO BULL
      if(dSL>dOpen) bprofit=true;  
   } 
   // Return value
   return bprofit;
}

// Coger valor del comentario
double GetProfitComment(int ithread)
{
   double dProfit=0;
   int iposini=0;
   int iposend=0;
   string scomment="";
   // Control Todo limpio
   if(ATREND[ithread][0]==0)
   {
      dProfit=Cacc.Equity();
      return dProfit;
   }
   // Cargar primera operaciÃ³n de array
   if(!cPos.SelectByTicket(ATREND[ithread][0]))
   {
      vtext="Error en GetProfitComment seleccionado ticket "+IntegerToString(ATREND[ithread][0])+". Ãltmo error encontrado:"+IntegerToString(GetLastError())+".No se evaluarÃ¡.";
      ENUMTXT = PRINT;
      expertLog();
      return -1;
   }
   scomment=cPos.Comment();
   iposini=StringFind(scomment,"(",0);
   if(iposini<0) return -1;
   iposini+=1;
   iposend=StringFind(scomment,")",iposini);
   iposend=iposend-iposini;
   if(iposend<0) return -1;
   scomment=StringSubstr(scomment,iposini,iposend);
   dProfit=StringToDouble(scomment);
   if(dProfit<=0) return -1;
   return dProfit;
}

short CheckAllThreadProfit()
{
   for(int i=0;i<9;i++)
   {
      // Sólo si el hilo tiene ops
      if(ATREND[i][0]>0)
      {
         CheckThreadProfit(i);
      }
   }
   return 1;
}

short CheckThreadProfit(int ithread)
{
   double dhandicap=0;
   double dProfitOp=0; // Control del profit de las operaciones actuales
   double dOpadd=-0.25; // add 0.25 by op.
   ulong lticket=0;
   
   // Coger el valor mÃ­nimo con el que el usuario asume salirse
   dhandicap=(iExitProfitStep*(-1));
   // Si estÃ¡ en apertura de mercado contar sÃ³lo el 50% de ganancias
   if(bOpenMarket)
   {
      dhandicap=(dhandicap/2);
   }
   
   // Si el bot se ha reseteado
   if(ATRENDPROFIT[ithread]==0)
   //if(ATRENDPROFIT[ithread]>0) // Test funtion
   {
      ATRENDPROFIT[ithread]=GetProfitComment(ithread);
   }
   // Recorrer hilo de operaciones para ir sumando los handicap
   for(int i=0;i<99;i++)
   {
      lticket=ATREND[ithread][i];
      if(lticket==0)
      {
         i=99;
         // Ya tengo todos los hadicap. Equity tiene encuenta las operaciones contando SWAP
         dhandicap=Cacc.Equity()+dhandicap;
         if(dhandicap>ATRENDPROFIT[ithread] || dProfitOp>iExitProfitStep)
         {
            return CloseThisThread(ithread);
         }
      }
      else
      {   
         if(!cPos.SelectByTicket(lticket))
         {
            vtext="Error en CheckThreadProfit seleccionado ticket "+IntegerToString(lticket)+". Ãltmo error encontrado:"+IntegerToString(GetLastError())+".No se evaluarÃ¡.";
            ENUMTXT = PRINT;
            expertLog();
            continue;
         }
         dhandicap+=getComisionPos();
         dhandicap+=cPos.Swap();  
         // Control por ops abiertas
         dProfitOp+=cPos.Profit();
         // Por cada op 25 cnts
         dProfitOp+=dOpadd;
         dProfitOp+=getComisionPos();
         dProfitOp+=cPos.Swap(); 
      }        
   }
   // Bien
   return 0;  
}

// Cerrar hilo. Todo menos el ticket actual
short CloseThisThread(int ithread)
{
   // Recorrer todas las posiciones
   double dProfit=0;
   ulong lmagic;
   int ipos=0;
   
   bool bnewMision=true;
   dProfit=Cacc.Equity()-ATRENDPROFIT[ithread];
   // ConfirmaciÃ³n CloseThisThread
   ulong aticket[99];
   // Recorrer todas las posiciones
   for(int i=0;i<PositionsTotal();i++) // returns the number of current positions
   {
      if(!cPos.SelectByIndex(i))
      {
         vtext="Error al seleccionar orden función CloseThisThread. Error = "+IntegerToString(GetLastError());
         ENUMTXT = PRINT;
         expertLog();
         continue;
      }
      // Control sólo hilo desado
      lmagic=cPos.Magic();
      // Seleccionar deal
      if(ithread!=(int)(lmagic-MAGICTREND)) continue;
      if(_Symbol==cPos.Symbol())
      {   
         aticket[ipos]=cPos.Ticket();
         ipos++;
      }    
   }
   /// CLOSE ALL
   for(int i=0;i<ipos;i++)
   {
      if(!cTrade.PositionClose(aticket[i]))
      {
         vtext="Error en CloseThisThread cerrar el ticket "+IntegerToString(aticket[ipos])+" error:"+IntegerToString(GetLastError());
         ENUMTXT = PRINT;
         expertLog();
         return -1;
      }
   } 
   // Nuevo valor de profit
   ATRENDPROFIT[ithread]=Cacc.Equity();
   // Finalizados Hilo
   vtext="CloseThisThread : Hilo cerrado "+IntegerToString(cPos.Magic())+" con ganancias: "+DoubleToString(dProfit,2)+" "+Cacc.Currency()+"." ;
   ENUMTXT = PRINT;
   expertLog();
   // Bien
   return 1;
}



//////////////////////////////////////////////////////////////////////////////////////////////////////////

short CheckForOpen()
{
   int ifreepos=0;
   double TP0=0.0;
   double dLotOpen=Lots;
   double dCommOpen=0.0;
   double dAddSpread=0.00;
   //Doble lote en horas de baja actividad
   datetime dNow=TimeCurrent();
   MqlDateTime strdate;
   
  
   //Recalc CENT
   dLotOpen=dLotOpen*iCent;
// Si hay mucho movimiento salirse
   if(iFrancisca < SymbolInfo.Spread())
   {
      vtext="El Spread actual "+IntegerToString(SymbolInfo.Spread())+" es superior al máximo configurado en el robot.";
      ENUMTXT = PRINT;
     // expertLog();
      return -1;   
   }
   // Control de hilos disponibles
   if(iMaxThead<=0)
   {
      vtext="El parámetro de usuario de Hilos se ha desactivado.";
      ENUMTXT = PRINT;
      //expertLog();      
      return 0;   
   }
   // Control de desactivaciÃ³n si el mercado va a abrir
   if(CheckOpenMarket()==false) return 0;
//--- additional checking
   if(TerminalInfoInteger(TERMINAL_TRADE_ALLOWED))
   {
      // Control de licencias por suscripciÃ³n
      if(CheckSilverEnd()==0) return -1;
      // Tipo de tendencia
      // Obtener posicion de array disponible
      ifreepos=GetFreePos();
      if (ifreepos < 0)
      {
         vtext="No se ha creado una nueva orden al haber llegado al mÃ¡ximo de hilos.";
         ///expertLog();   // Texto pintado en funcion GetFreePos
         return 0;  
      }    
      // Cambiar mode del bot
      enumbotmode=WORKING_DAY;
      
      // Reset contador de beneficios
      ATRENDPROFIT[ifreepos]=Cacc.Balance();
      // Pintar tendencia. SÃ³lo cuando se va a abrir
      // Bar is new  
      checkBardir();
      // Control doble lote
      // Controlar doble lote
      TimeToStruct(dNow,strdate);
      // Peso del Spread aÃ±adir al SL
      dAddSpread=MathAbs(SymbolInfo.Bid()-SymbolInfo.Ask());
      if(dAddSpread>(iFrancisca*pips)) dAddSpread=iFrancisca*pips;
      // Control de comisiÃ³n
      dCommOpen+=iComisionPips;
      // COMENTARIO MAX 32 CHAR
      ACOMMENT[ifreepos]=GetTCode();
      ACOMMENT[ifreepos]=BOTNAME+" ("+ACOMMENT[ifreepos]+") : 0";
      // Inicio de limites de hilo. TP + iFrancisca. Saltará en ese precio + otra francisca
      dLPRICE[ifreepos]=SymbolInfo.Ask();
      dLPRICE[ifreepos]-=((TakeProfit+iFrancisca)*pips);
      dHPRICE[ifreepos]=SymbolInfo.Bid();
      dHPRICE[ifreepos]+=((TakeProfit+iFrancisca)*pips);
      switch(ENUMBARDIR)
      {
         case POSITION_TYPE_SELL:
            // Asignar el numero mÃ¡gico de ventas   
            cTrade.SetExpertMagicNumber(ATRENDBOT[ifreepos]);
            // Control de SWAPMT5|Watch!7
            if(SymbolInfo.SwapShort()<0)dCommOpen+=4;
            TP0=SymbolInfo.Bid()-(TakeProfit*pips)-(dCommOpen*pips)-dAddSpread;
            if(!cTrade.Sell(dLotOpen,_Symbol,0,0,TP0,ACOMMENT[ifreepos]))
            {
               vtext="Se ha producido el error "+IntegerToString(GetLastError())+" al abrir una operaciÃ³n de "+DoubleToString(Lots)+".";
               ENUMTXT = PRINT;
               expertLog();
            }
            return 1;
            break;  
         case POSITION_TYPE_BUY:
            // Asignar el numero mÃ¡gico de ventas
            cTrade.SetExpertMagicNumber(ATRENDBOT[ifreepos]);
            // Control de SWAP
            if(SymbolInfo.SwapLong()<0)dCommOpen+=4;
            TP0=SymbolInfo.Ask()+(TakeProfit*pips)+(dCommOpen*pips)+dAddSpread;
            if(!cTrade.Buy(dLotOpen,_Symbol,0,0,TP0,ACOMMENT[ifreepos]))
            {
               vtext="Se ha producido el error "+IntegerToString(GetLastError())+" al abrir una operaciÃ³n de "+DoubleToString(Lots)+".";
               ENUMTXT = PRINT;
               expertLog();
            }
            return 1; 
            break;
      }     
   }
   return 0;
}

// Obtener una posicion libre en el array
int GetFreePos()
{  
   // Evaluar cuenta para NÂº de hilos MAX 9. Cada 1500 1 hilo
   double dEquity=0;
   iHilos=0;
   
   dEquity=NormalizeDouble(AccountInfoDouble(ACCOUNT_EQUITY),2);
   iHilos=(int)MathFloor(dEquity/1250);
   enumthread=FOUNDS;
   if(iHilos<1)iHilos=1;
   if(iHilos>iMaxThead) 
   {
      iHilos=iMaxThead;
      enumthread=MAXPARM;
   }
   if(iHilos>9)iHilos=9;
   for(int i=0;i<iHilos;i++)
   {
      if(ATRENDBOT[i]==0)
      {              
         ATRENDBOT[i]=MAGICTREND+i;
         vtext="Número de hilos disponibles para la cuenta de "+(string)dEquity+" "+AccountInfoString(ACCOUNT_CURRENCY)+": "+IntegerToString(iHilos);
         ENUMTXT = PRINT;
       //  expertLog();
         return i;
      }
   }
   return -1;
}
// No operar en navidad ni el 1 de agosto (+- 7 dÃ­as).
short BotVacation()
{
   datetime dNow=TimeCurrent();
   MqlDateTime strdate;
   // Si esta desactivado ok
   if(!bHollidays) return 1;
   // Esta activado
   TimeToStruct(dNow,strdate);
   // Si es navidad
   if((strdate.mon==12 && strdate.day>19) || (strdate.mon==1 && strdate.day<7) )
   {
         vtext="Desactivada apertura en vacaciones de Navidad. FELIZ NAVIDAD.";
         enumbotmode=CHRISTMAS;
         //ENUMTXT = PRINT;
         //expertLog();
         return 0;
   }
   // Vacaciones de verano
   if((strdate.mon==7 && strdate.day>25) || (strdate.mon==8 && strdate.day<5) )
   {
         vtext="Desactivada apertura en vacaciones de verano. El bot esta de vacas.";
         enumbotmode=SUMMER_TIME;
         //ENUMTXT = PRINT;
         //expertLog();
         return 0;
   }
   // Bien
   return 1;
}

short MarketClosing()
{
   datetime dNow=TimeCurrent();
   uint session_index=0;
   ENUM_DAY_OF_WEEK eday;
   MqlDateTime strdate;
   short saddhour=4;
   long lmagic=0; 
   double dprice=0.0;
   
   // Check date 
   TimeToStruct(dNow,strdate);
   eday=(ENUM_DAY_OF_WEEK) strdate.day_of_week;
   SymbolInfo.Name(_Symbol);
   SymbolInfo.Refresh();
   SymbolInfo.RefreshRates();
   
   enumthread=MAXPARM;
   enumbotmode=WORKING_DAY;
   
   // No operar la 1a hora de apertura
   if(strdate.day_of_week==1 && strdate.hour<saddhour)
   {
      if(strdate.min==0)
      {
         vtext="Desactivada la creaciÃ³n de nuevas operaciones en la primera hora de apertura de mercado.";
         ENUMTXT = PRINT;
         expertLog();
      }
      return 0;
   }
   // Control Ãºltimo dÃ­a de la semana de forex
   if(bSoftFriday==true)
   {
      if(strdate.day_of_week<4) return 1;
      // Control jueves tarde / noche
      if(strdate.day_of_week==4 && (strdate.hour)<shourclose) return 1; 
      if(strdate.min==0)
      {
         vtext="Ãltimo dÃ­a de mercado con parÃ¡metro de nuevas operaciones desactivado bSoftFriday.";
         ENUMTXT = PRINT;
         expertLog();
      }
      enumthread=ISFRIDAY;
      enumbotmode=SOFT_FRIDAY;
      return 0;      
   }
   // Control viernes real
   if(strdate.day_of_week==5 && (strdate.hour)>=shourclose) return 0; 
   return 1;
}

///////////////////// Funtions get steps
ulong GetStep(string scomment)
{
   ulong lstep=0;
   // Localizar el array del ticket
   int ipos=0;
   ipos=(int)(cPos.Magic()-MAGICTREND);
   // Si no tiene valor asignar por defecto
   if(StringLen(scomment)<=0)
   {
      // COMENTARIO MAX 32 CHAR
      scomment=GetTCode();
      scomment=BOTNAME+" ("+scomment+") : 5";
      lstep=5;
      ACOMMENT[ipos]=scomment;
   }
   else
   {
      // Control de comentario vacio. Calcula por tamaÃ±o del lote
      scomment=StringSubstr(scomment, (StringLen(cPos.Comment())-2));
      // Control de comentario vacio. Calcula por tamaÃ±o del lote
      StringTrimLeft(scomment);
      lstep=StringToInteger(scomment);
   }
   return lstep;
}

// ------------------------------------------------------------------------------------------------------------------- //
// ------------------------------------------- SMARTINGALA CODE ------------------------------------------------------ //
// ------------------------------------------------------------------------------------------------------------------- //

// Comprueba si una operaciÃ³n esta en perdidas y llama a la funciÃ³n NewStep
int CheckNewStep()
{
   ulong lTicket=0;
   ulong lMagic=0;
   double dpricestep=0.0;
   double dnewprice=0.0;
   double dTP=0.0;
   double dNewTP=0.0;
   double dSL=0.0;
   double dCommOpen=0;
   double dPipStep=0;
   double dPriceNow=0;
   double dNextScalp=0;
   int ipos=0;
   ulong lstep,lNewStep=0;
   ulong sZgravityStep;
   string scomment;
   datetime dOpenticket;
   // Control de  comisiÃ³n
   dCommOpen+=(iComisionPips*pips);
   // Coger el parÃ¡metro que ha seleccionado el usuario
   sZgravityStep=GetGravityStep();
   // No saturar el alert del bot
   datetime dNow=TimeCurrent();
   ENUM_POSITION_TYPE TYPE_POS=WRONG_VALUE;
   for(int i=0;i<PositionsTotal();i++) // returns the number of current positions
   {
      if(!cPos.SelectByIndex(i))
      {
         Print("Error al seleccionar orden. Error = ",GetLastError());
         continue;
      }
      lTicket=cPos.Ticket();
      if(_Symbol!=cPos.Symbol()) continue;
      dOpenticket=cPos.Time();

      // Control de ser el mÃ¡x/min value. SÃ³lo trabajar con los 2 edges Bear/BULL
      ipos=(int)(cPos.Magic()-MAGICTREND); 
      // Si Esta en positivo siguiente
      if(cPos.Profit()>0 ) continue;
      dPriceNow=cPos.PriceCurrent();
      dSL=cPos.StopLoss();
      // Comprobar cobertura. Volver a cargar cPos porque la funciÃ³n carga el resto de tickets
      TYPE_POS=cPos.PositionType();
      // Check Bot
      dpricestep = cPos.PriceOpen();
      // Obtener TP
      dTP=cPos.TakeProfit();
      // Control de comentario
      scomment=cPos.Comment();
      // // Si el comentario estÃ¡ vacio coger el array
      if(StringLen(scomment)<=0)
      {
         scomment=ACOMMENT[ipos];
      }
      // Si sigue sin comentario correcto poner comentario default
      lstep=GetStep(scomment);
      lMagic=cPos.Magic();
      lNewStep=lstep+1;
      // Esta funciÃ³n sÃ³lo llega hasta step lateral
      // Poner Nuevos SL/TP del hilo
      if(lstep>=sZgravityStep)
      {
         enumbotmode=ZERO_GRAVITY;
         vtext="Gravedad 0 activada. Llamando a funciÃ³n de ZeroGravity.";
         continue;
      }
      // SÃ³lo trabajar con la Ãºltima op.
      if(isEdge(ipos)==0) continue;
      // COMENTARIO MAX 32 CHAR
      StringReplace(scomment,": "+IntegerToString(lstep),": "+IntegerToString(lNewStep)); 
      ///////////////////////////////////////////////////////////////////////////////////
      // Dependiendo tipo de posiciÃ³n
      if(TYPE_POS==POSITION_TYPE_SELL)
      {     
         // Original Venta
         dNextScalp=(dHPRICE[ipos]+(iFrancisca*pips));
         if(dPriceNow<dNextScalp) continue; 
         dnewprice=NormalizeDouble(SymbolInfo.Bid(),Digits());
         // Asignar el numero mÃ¡gico 
         cTrade.SetExpertMagicNumber(lMagic);
         dNewTP=MathAbs(dpricestep-dnewprice);  
         // 1 Generar nueva posciÃ³n en dir contraria
         dNewTP=NormalizeDouble(dnewprice+dNewTP+dCommOpen+(iFrancisca*2*pips),Digits());
         // Comprobar precio en zona verde
         dNewTP=GetGreenPrice(dNewTP,POSITION_TYPE_BUY);
         dSL=NewStep(dNewTP,lNewStep,sZgravityStep,scomment,POSITION_TYPE_BUY,lMagic);
         // Continue si NewStep es 0
         if(dSL==0) continue;
         // Save comment
         ACOMMENT[ipos]=scomment;
      }
      else
      {
         // Original Compra
         dNextScalp=(dLPRICE[ipos]-(iFrancisca*pips));
         if(dPriceNow>dNextScalp) continue;
         // Asignar el numero mÃ¡gico 
         cTrade.SetExpertMagicNumber(lMagic);  
         dnewprice=NormalizeDouble(SymbolInfo.Ask(),Digits());  
         dNewTP=MathAbs(dpricestep-dnewprice);  
         // 1 Generar nueva posciÃ³n
         dNewTP=NormalizeDouble(dnewprice-dNewTP-dCommOpen-(iFrancisca*2*pips),Digits());
         dNewTP=GetGreenPrice(dNewTP,POSITION_TYPE_SELL);
         dSL=NewStep(dNewTP,lNewStep,sZgravityStep,scomment,POSITION_TYPE_SELL,lMagic);
         // Continue si NewStep es 0
         if(dSL==0) continue;
         // Save comment
         ACOMMENT[ipos]=scomment;     
      }
      // 2 Poner SL de posiciÃ³n con problemas
      if(!cTrade.PositionModify(lTicket,dSL,dTP))
      {
         vtext="Error al actualizar CheckNewStep en ticket "+IntegerToString(cPos.Ticket())+" error:"+IntegerToString(GetLastError());
         ENUMTXT = PRINT;
         expertLog();
         return -1;
      }  
   }
   // Bien
   return 1;
}

ulong GetGravityStep()
{
   ulong lstep=99;
   switch(EZGRAVITY)
   {
      case STEP_3:
         lstep=3;
         break;
      case STEP_4:
         lstep=4;
         break;
      case STEP_5:
         lstep=5;
         break;
      case STEP_6:
         lstep=6;
         break;
      default:
         lstep=-1;
         break;    
   }
   return lstep;
}

int isEdge(int ipos)
{
   int iedge=0;
   ulong uticket=0;
   int size=ArraySize(ATREND);
   // solv array out of range
   if(size<ipos) 
   {
      return iedge;
   }
   uticket=cPos.Ticket();
   
   // Recorrer array
   for(int i=0;i<99;i++) 
   {
      if(ATREND[ipos][i]==0)
      {
         i=99;
      }
      else
      {
         if(ATREND[ipos][i]==uticket) 
         {
            iedge=1;
         }
         else
         {
            iedge=0;
         }
      }
   }
   // Retorno
   return iedge;
}

double NewStep(double newTP,ulong lstep,ulong sZgravity,string scoment,ENUM_POSITION_TYPE TYPE_POS,ulong lMagic)
{
   double LotStep=0.0;
   double LotOrig=0.00;
   double dSwap=0.0;
   double dSL = 0.00;
   double dTP = 0.00;
   
   // TamaÃ±o del lote
   LotOrig=cPos.Volume();
   LotStep=(LotOrig*2)+(Lots*iCent);
   // Control ZGravity
   if((lstep>=sZgravity))
   {
      LotStep=GetLotStep(lstep);
      // Gravedad 0
      vtext="NewStep: Lote en gravedad 0 calculado: "+DoubleToString(LotStep)+".";
      // Resetar comentario a op. maxima normal de ZeroGravity
      StringReplace(scoment,": "+IntegerToString(lstep),": "+IntegerToString(sZgravity)); 
   }
   // Si esta en gravedad 0 no hacer nada.
   if(LotStep<=0) return 0;
   // Asignar el numero mÃ¡gico 
   cTrade.SetExpertMagicNumber(lMagic); 
   switch(TYPE_POS)
   {
      case POSITION_TYPE_SELL:
         // Control de SWAP
         if(SymbolInfo.SwapShort()<0)dSwap=4;
         // Calcula TP si la operaciÃ³n es menor a G0
         if((lstep<sZgravity)) dTP=newTP-(dSwap*pips);
         if(!cTrade.Sell(LotStep,_Symbol,0,dSL,dTP,scoment))
         {
            vtext="Se ha producido el error "+IntegerToString(GetLastError())+" al abrir una operaciÃ³n de "+DoubleToString(LotStep)+".";
            ENUMTXT = PRINT;
            expertLog();
            return -1;
         }
         vtext=scoment+".TamaÃ±o lote:"+DoubleToString(LotStep)+".";
         break;  
      case POSITION_TYPE_BUY:
         // Control de SWAP
         if(SymbolInfo.SwapLong()<0)dSwap=4;
         // Calcula TP si la operaciÃ³n es menor a G0
         if((lstep<sZgravity)) dTP=newTP+(dSwap*pips);
         if(!cTrade.Buy(LotStep,_Symbol,0,dSL,dTP,scoment))
         {
            vtext="Se ha producido el error "+IntegerToString(GetLastError())+" al abrir una operaciÃ³n de "+DoubleToString(LotStep)+".";
            ENUMTXT = PRINT;
            expertLog();
            return -1;
         }
         vtext=scoment+".TamaÃ±o lote:"+DoubleToString(LotStep)+".";
         break;
   }
   ENUMTXT = PRINT;
   expertLog();
   
   // Contar ops.
   if(countbot()<0) return -1;
   // Bien
   return dTP;
}
//              ------------------------------------------------------------------------------------------------------------------- //
//              ------------------------------------------- SMARTINGALA CODE ------------------------------------------------------ //
//              ------------------------------------------------------------------------------------------------------------------- //

// ------------------------------------------------------------------------------------------------------------------- //
// ------------------------------------------- FRANCISCADA CODE ------------------------------------------------------ //
// ------------------------------------------------------------------------------------------------------------------- //
short goFrancisca()
{
   // Coger las posiciones del symbolo y de los nÂº mÃ¡gicos reservados
   ENUM_POSITION_TYPE TYPE_POS;
   double Dprice=0;
   double dOpen=0;
   double dOldTP=0;
   double dOldSL=0;
   double DnewTP=0.0;
   double DnewSL=0.0;
   ulong lTicketAnt=0;
   ulong lTicket=0;
   long lmagic=0;
   int ipos=0;
   bool bsold=false;

   //Asignar Franciscada
   switch(enumfrancisca)
   {
      case SIN_FRANCISCA:
         iFrancisca=0;
         break;
      case FRANCISCA_10:
         iFrancisca=10;
         break;
      case FRANCISCA_20:
         iFrancisca=20;
         break;
   }
   // Recorrer todas las posiciones
   for(int i=0;i<PositionsTotal();i++) // returns the number of current positions
   {
      if(!cPos.SelectByIndex(i))
      {
         vtext="Error al seleccionar orden funciÃ³n francisca. Error = "+IntegerToString(GetLastError());
         ENUMTXT = PRINT;
         expertLog();
         continue;
      }
     // vtext="Check Franciscada called for.";
      //ENUMTXT = PRINT;
      //expertLog();
      lTicket=cPos.Ticket();
      lmagic=cPos.Magic();
      if (_Symbol==cPos.Symbol() && (IsMyMagic(lmagic)>0))
      {
         TYPE_POS=cPos.PositionType();
         ipos=(int)(cPos.Magic()-MAGICTREND);
         dOpen=cPos.PriceOpen();
         dOldSL=cPos.StopLoss();
         dOldTP=cPos.TakeProfit();
         Dprice=cPos.PriceCurrent();
         // Comprobar si esta cerca del SLMax para no hacer nada
         DnewSL=GetSLMax();
         if(MathAbs(dOldSL==DnewSL)) continue;
         if(TYPE_POS==POSITION_TYPE_SELL)
         {
            DnewSL=dOpen-(TakeProfit*pips);
            // Mision cumplida. Nueva misiÃ³n
            if((dOldSL>0) && (dOldSL<DnewSL))
            {
               // Resto de cambios
               DnewSL=NormalizeDouble((Dprice+(iFrancisca*pips)),Digits());
               ///DnewTP=NormalizeDouble(Dprice-(iFrancisca*2*pips),Digits());
               // Nueva misiÃ³n 30/10 pips. Sino serÃ­a 60/10 muy poco beneficio
               //DnewTP=NormalizeDouble(Dprice-((TakeProfit+iFrancisca)*0.5*pips),Digits());
               DnewTP=NormalizeDouble(Dprice-((TakeProfit)*pips),Digits());
            }
            else
            {
               // Primer cambio
               DnewSL=NormalizeDouble((Dprice+(iFrancisca*pips)),Digits());
               DnewTP=NormalizeDouble((dOldTP-(iFrancisca*pips)),Digits());
            }
            
            // Control mÃ­nimo SL por debajo de precio
            if(DnewSL<Dprice) DnewSL=NormalizeDouble((Dprice+(iFrancisca*pips)),Digits());  
         }
         else  //// BUY
         {
            DnewSL=dOpen+(TakeProfit*pips);
            if(dOldSL>DnewSL)
            {
               // Resto de cambios
               DnewSL=NormalizeDouble((Dprice-(iFrancisca*pips)),Digits());
               ////DnewTP=NormalizeDouble((Dprice+(iFrancisca*2*pips)),Digits());
               // Nueva misiÃ³n. 30/10 pips. Sino 60/10 muy poco beneficio
               //DnewTP=NormalizeDouble((Dprice+((TakeProfit+iFrancisca)*0.5*pips)),Digits());
               DnewTP=NormalizeDouble((Dprice+((TakeProfit)*pips)),Digits());
            }
            else
            {
               // Primer cambio
               DnewSL=NormalizeDouble((Dprice-(iFrancisca*pips)),Digits());
               DnewTP=NormalizeDouble((dOldTP+(iFrancisca*pips)),Digits());
            } 
            // Control mÃ­nimo SL por debajo de precio
            if(DnewSL>Dprice) DnewSL=NormalizeDouble((Dprice-(iFrancisca*pips)),Digits());
         }
         // Si hay que actualiar por tp de la posiciÃ³n
         if(MathAbs(Dprice-dOldTP)<(iFrancisca*pips))
         { 
            // Actualizar Posicion
            if(!cTrade.PositionModify(lTicket,DnewSL,DnewTP))
            {
               vtext="Error al actualizar Franciscada en ticket "+IntegerToString(lTicket)+" error:"+IntegerToString(GetLastError());
               ENUMTXT = PRINT;
               expertLog();
               return -1;
            }
            // Matar ticket anteriores y del mismo step menos este
            if(FrancisKillThread(dOldTP)<0) return -1;
            vtext="ActalizaciÃ³n Franciscada en ticket "+IntegerToString(lTicket)+" Nuevo SL:"+DoubleToString(DnewSL)+", TP:"+DoubleToString(DnewTP)+".";
            ENUMTXT = PRINT;
            expertLog();
         }
      }  
   }
   // Franciscada finalizada
   return 1;
}
// Funtion will be kill previous op of Franciscana triggered correctly
// Cerrar tiket contrarios al q proboco el kill
short FrancisKillThread(double dTP)
{
   // Recorrer todo el hilo, cerrar tiket de step -1 y step menos el de francisca.
   ulong lticket=0;
   double dSL=0;
   int ithread=0;
   // Coger el el hilo
   ithread=(int)cPos.Magic()-MAGICTREND;
   for(int ipos=0;ipos<99;ipos++) // recorrer dimesion pos
   {
      if(ATREND[ithread][ipos]==0)
      {
         // Final de hilo
         ipos=99;
      }
      else
      {
         lticket=ATREND[ithread][ipos];
         if(!cPos.SelectByTicket(lticket))
         {
            vtext="Error al seleccionar orden funciÃ³n FrancisKill. Error = "+IntegerToString(GetLastError());
            ENUMTXT = PRINT;
            expertLog();
            return -1;
         }
         dSL=cPos.StopLoss();
         
         // Si estÃ¡ aqui es para cerrar.SL=TP
         if(_Symbol==cPos.Symbol() && dSL==dTP)
         {   
            if(!cTrade.PositionClose(lticket))
            {
               vtext="Error en FrancisKill cerrar el ticket "+IntegerToString(cPos.Ticket())+" error:"+IntegerToString(GetLastError());
               ENUMTXT = PRINT;
               expertLog();
               return -1;
            }
            vtext="FrancisKill realizado.Ticket cerrado: "+IntegerToString(lticket);
            ENUMTXT = PRINT;
            expertLog();   
         }
      }

   }
   // Bien
   return 1;
}

// Retorna a funciÃ³n francisca que la op tiene activada SLMax
double GetSLMax()
{
   double dOpen=0.00;
   double dSL=0.00;
   ENUM_POSITION_TYPE TYPE_POS;
   TYPE_POS=cPos.PositionType();
   dOpen=cPos.PriceOpen();
   dSL=cPos.StopLoss();
   if(TYPE_POS==POSITION_TYPE_SELL)
   {
      dOpen=NormalizeDouble(dOpen-((TakeProfit)*pips),Digits());
   }
   else
   {
      dOpen=NormalizeDouble(dOpen+((TakeProfit)*pips),Digits());
   }
   // Retornar precio de SL
   return dOpen;
}
  
//              ------------------------------------------------------------------------------------------------------------------- //
//              ------------------------------------------- FRANCISCADA CODE ------------------------------------------------------ //
//              ------------------------------------------------------------------------------------------------------------------- //

// ------------------------------------------------------------------------------------------------------------------------ //
// ---------------------------------------------- ZERO GREVITY CODE ------------------------------------------------------- //
// ------------------------------------------------------------------------------------------------------------------------ //
/////    FUNCION PARA IGUALAR LOTE SI SE VA POR LOS EXTREMOS
short EqualZero()
{
   ulong sZgravityStep;
   double dLot,diff;
   // Coger el parÃ¡metro que ha seleccionado el usuario
   dLot=Lots*iCent;
   sZgravityStep=GetGravityStep();   
   for(int i=0;i<9;i++)
   {
      // Llamada hilos 
      diff=MathAbs(dLOTBear[i]-dLOTBULL[i]);
      if(diff>(dLot*2))
      {
         EqualZeroThread(i,sZgravityStep);
      }  
   }
   // Bien
   return 1;
}

short EqualZeroThread(int ithread,ulong sZgravityStep)
{
   ulong lticket=0;
   double dCurrentPrice=0;
   double dOpen=0;
   double dNewLot=0.00;
   ulong lstep;
   string scomment;
   bool bZero=false;
   ENUM_POSITION_TYPE TYPE_Break=WRONG_VALUE;
   // Recorrer hilo de operaciones para ir sumando los handicap
   dCurrentPrice=cPos.PriceCurrent();
   // Coger niveles
   for(int i=0;i<99;i++)
   {
      lticket=ATREND[ithread][i];
      if(lticket==0 || bZero==true)
      {
         i=99;
         if(bZero==false) return 1;
         // Los límites del hilo ya se han definido en la función llamada cada 5 min 1 vez.
         // Control de precio con respecto a lÃ­mites
         if((dCurrentPrice<dLPRICE[ithread]) && (dLOTBear[ithread] < dLOTBULL[ithread]))
         {
            TYPE_Break=POSITION_TYPE_SELL;
            dNewLot=(dLOTBULL[ithread]-dLOTBear[ithread]);
            dNewLot=NormalizeDouble(dNewLot,lotdecimal);
            return CreateOpZero(TYPE_Break,dNewLot,sZgravityStep);
         }
         if((dCurrentPrice>dHPRICE[ithread]) && (dLOTBULL[ithread] < dLOTBear[ithread]))
         {
            TYPE_Break=POSITION_TYPE_BUY;
            dNewLot=(dLOTBear[ithread]-dLOTBULL[ithread]);
            dNewLot=NormalizeDouble(dNewLot,lotdecimal);
            return CreateOpZero(TYPE_Break,dNewLot,sZgravityStep);
         }
         return 1;
      }
      else
      {   
         if(!cPos.SelectByTicket(lticket))
         {
            vtext="Error en BreakOPSLevel seleccionado ticket "+IntegerToString(lticket)+". Ãltmo error encontrado:"+IntegerToString(GetLastError())+".No se evaluarÃ¡.";
            ENUMTXT = PRINT;
            expertLog();
            continue;
         }
         // Reseteare niveles de operaciones de hilo
         dOpen=cPos.PriceOpen();
         // Coger tipo de op
         scomment=cPos.Comment();
         lstep=GetStep(scomment); 
         // No hacer nada mientras el hilo no se GZero
         if(lstep>=sZgravityStep) 
         {
            // Hacer llamada para cargar datos
            if(dHPRICE[ithread]<=0) 
            {
               if(SetLevelZero()<0) return -1;
            }
            bZero=true;
         }
      }        
   }		 
   // Bien
   return 1;
}


// FunciÃ³n comprobaciÃ³n rotura niveles diarios
short CheckBreakDayLevel()
{
   double dCurrent=0.00;
   double dlevel=0.00;
   // Coger nivel actual
   dCurrent=(SymbolInfo.Ask()+SymbolInfo.Bid())/2;
   // Si el mercado no va a abrir
   if(CheckOpenMarket()==false) return 1;
   // Control niveles rotos
   //dlevel=dSupport-(iFrancisca*pips);
   dlevel=dSupport;
   if(dCurrent<dlevel)
   {
      return BreakZero(POSITION_TYPE_SELL);
   }
   dlevel=dResistance;
   ///dlevel=dResistance+(iFrancisca*pips);
   if(dlevel<dCurrent)
   {
      return BreakZero(POSITION_TYPE_BUY);
   }
   // Bien
   return 1;
}

short BreakZero(ENUM_POSITION_TYPE TYPE_POS)
{
   ulong sZgravityStep;
   int ipos=0;
   // Coger el parÃ¡metro que ha seleccionado el usuario
   sZgravityStep=GetGravityStep();
      // Control de fecha
   if(timeCurent<dWaitBreakZero)
   {
      vtext="Fecha actual es inferior a "+DoubleToString(dWaitBreakZero);
      return 0;
   }
   // Check all Threads
   for(int i=0;i<9;i++) // returns los posibles hilos
   {
      if(BreakZeroThread(i,sZgravityStep,TYPE_POS)<0) return -1;
   }
   // Bien
   return 1;
}

short BreakZeroThread(int iThread,ulong sZgravityStep,ENUM_POSITION_TYPE TYPE_POS)
{
   ulong ticket;
   ulong lstep;
   ulong lNewstep;
   string scomment;
   double dLot=Lots*iCent;
   double dNewLot=0.00;

   // Coger el loteZero
   lNewstep=sZgravityStep+1;
   // Check all threads
   for(int x=0;x<99;x++)
   {
      // Control si encuentra parar.
      if(ATREND[iThread][x]==0)
      {
         x=99;
      }
      else
      {
         // Cargar el ticket Zero
         ticket=ATREND[iThread][x];  
         if(!cPos.SelectByTicket(ticket))
         {
            vtext="Error en BreakZeroThread seleccionado ticket "+IntegerToString(ticket)+". Ãltmo error encontrado:"+IntegerToString(GetLastError())+".No se evaluarÃ¡.";
            ENUMTXT = PRINT;
            expertLog();
            return -1;
         }
         // Coger tipo de op
         scomment=cPos.Comment();
         lstep=GetStep(scomment); 
         // No hacer nada mientras el hilo no se GZero
         if(lstep<sZgravityStep) continue;

         // Si llega aqui el hilo esta en GZero
         // Dependiendo de la ruptura duplicar 1 u otro lote
         if(TYPE_POS==POSITION_TYPE_SELL)
         {
            dNewLot=((dLOTBULL[iThread]*2)-dLOTBear[iThread]);
            dNewLot=NormalizeDouble(dNewLot,lotdecimal);
            // Control de 0 Lots. Si ya es doble en esa direcciÃ³n no hacer mÃ¡s ops
            if(dNewLot<dLot) return 0;
            vtext="Detectado rotura de soportes. Creando operaciÃ³n Bear:"+DoubleToString(dNewLot);
            ENUMTXT = PRINT;
            expertLog();      
         }
         else
         { // New op tipo BULL
            dNewLot=((dLOTBear[iThread]*2)-dLOTBULL[iThread]);
            dNewLot=NormalizeDouble(dNewLot,lotdecimal);
            // Control de 0 Lots.
            if(dNewLot<dLot) return 0;
            vtext="Detectado rotura de resistencias. Creando operaciÃ³n BULL."+DoubleToString(dNewLot);
            ENUMTXT = PRINT;
            expertLog();   
         }
         // Create new op to doble dir.
        return CreateOpZero(TYPE_POS,dNewLot,lNewstep);
      }
   }
   
   // Bien
   return 1;
}
// 

// Nuevas operaciones ZeroGravity. Se le pasa el tipo,lote y step q se crearÃ¡
short CreateOpZero(ENUM_POSITION_TYPE TYPE_POS,double dZeroLot,ulong sNewStep)
{
   ulong lstep=0;
   ulong lMagic;
   string scomment;
   int iThread;
   double dLot=Lots*iCent;
   // Control 0 Lots.
   if(dZeroLot<dLot) return 0;
   // Tiene cargada la Ãºltima operaciÃ³n del hilo
   scomment=cPos.Comment();
   lstep=GetStep(scomment);
   // Resetear comentario
   StringReplace(scomment,": "+IntegerToString(lstep),": "+IntegerToString(sNewStep)); 
   // Asignar el numero mÃ¡gico 
   lMagic=cPos.Magic();
   iThread=(int)(lMagic-MAGICTREND);
   cTrade.SetExpertMagicNumber(lMagic); 
   // Dependiendo de la operaciÃ³n a crear
   if(TYPE_POS==POSITION_TYPE_SELL)
   {
      // Crear Bear
      if(!cTrade.Sell(dZeroLot,_Symbol,0,0,0,scomment))
      {
         vtext="CreateOpZero:Se ha producido el error "+IntegerToString(GetLastError())+" al abrir una operaciÃ³n de "+DoubleToString(dZeroLot)+".";
         ENUMTXT = PRINT;
         expertLog();
         return -1;
      }
      
   }
   else
   {
      // Crear BULL
      if(!cTrade.Buy(dZeroLot,_Symbol,0,0,0,scomment))
      {
         vtext="CreateOpZero:Se ha producido el error "+IntegerToString(GetLastError())+" al abrir una operaciÃ³n de "+DoubleToString(dZeroLot)+".";
         ENUMTXT = PRINT;
         expertLog();
         return -1;
      }  
   }
   vtext="CreateOpZero: se ha aÃ±adido nueva operaciÃ³n en hilo "+IntegerToString(iThread)+":"+DoubleToString(dZeroLot)+".";;
   ENUMTXT = PRINT;
   expertLog();    
   // Bien
   return 1;
}
// Función with 3 roles:
// 1 Set G0 Bear and G0 Bull prices (first time detect one G0 operation on thread)
// 2 Reset TP/SL if the older op is G-1.
// 3 Set SL on G0 ops.
short SetLevelZero()
{
   ulong sZgravityStep;
   int ipos=0;
   // Coger el parÃÂ¡metro que ha seleccionado el usuario
   sZgravityStep=GetGravityStep();
// Check all Threads
   for(int i=0;i<9;i++) // returns los posibles hilos
  {
     if(SetLevelZeroThread(i,sZgravityStep)<0) return -1;
  }
  // Bien
   return 1;
}
// Recorrer las op del hilo.
short SetLevelZeroThread(int iThread, ulong sZgravityStep)
{
   ulong ticket=0;
   ulong lstep=0;
   string scomment;
   // Control de soportes y resistencias si dHPRICE[ifreepos]=0
   bool bSetZeroZone=false;
   double dBearZone=0;
   double dBullZone=10000;
   ENUM_POSITION_TYPE TYPE_POS;
   double dNewSL,dOpen,dCurrent,ddiff=0.00;
   
   // Check all threads
   for(int x=0;x<99;x++)
   {
      // Control si encuentra parar.
      if(ATREND[iThread][x]==0)
      {
         x=99;
         // Si hay que guardar los niveles
         if(bSetZeroZone)
         {
            dLPRICE[iThread]=dBearZone;
            dHPRICE[iThread]=dBullZone;
            vtext="SetLevelZeroThread. Definición limites zona 0. ZeroBear:"+DoubleToString(dLPRICE[iThread])+". ZeroBULL:"+DoubleToString(dHPRICE[iThread])+".";
            ENUMTXT = PRINT;
            expertLog();
         }
      }
      else
      {
         // Cargar el ticket Zero
         ticket=ATREND[iThread][x];  
         if(!cPos.SelectByTicket(ticket))
         {
            vtext="Error en SetLevelZeroThread seleccionado ticket "+IntegerToString(ticket)+". Último error encontrado:"+IntegerToString(GetLastError())+".No se evaluará.";
            ENUMTXT = PRINT;
            expertLog();
            return -1;
         }
         // Coger tipo de op
         dOpen=cPos.PriceOpen();
         TYPE_POS=cPos.PositionType();
         // Coger el menor Bull y el mayor SELL para la región G0.
         if(TYPE_POS==POSITION_TYPE_SELL)
         {
            if(dBearZone<dOpen) dBearZone=dOpen;
         }
         else
         { // Operaciones BULL
            if(dBullZone>dOpen) dBullZone=dOpen;
         }
         scomment=cPos.Comment();
         lstep=GetStep(scomment);
         
         // Control hilo G0 y G1
         if(lstep>=sZgravityStep)
         {
            // El hilo es G0. Check si los niveles se han definido.
            if(bSetZeroZone==false)
            {
               if(dHPRICE[iThread]<=0) bSetZeroZone=true;
            }
         }
          
         // Si la más antigua es G-1 comprobar limites
         if((x==0) && ((lstep+1)==sZgravityStep))
         {
            if(ClearTP()<0) return -1;
         }
         // Parte SL de operaciones G0
         if(cPos.Profit()<0) continue;
         
         dNewSL=cPos.StopLoss();
         if(dNewSL>0) continue;
         dCurrent=cPos.PriceCurrent();
         ddiff=MathAbs(dOpen-dCurrent);
         // SL si el precio esta mÃÂ¡s de 4 TP
         if(ddiff<(4*TakeProfit*pips)) continue;
         // Control de hilo en esa dir.
         if(TYPE_POS==POSITION_TYPE_SELL)
         {
            dNewSL=dOpen-(TakeProfit*pips);
         }
         if(TYPE_POS==POSITION_TYPE_BUY)
         {
            dNewSL=dOpen+(TakeProfit*pips);
         }
         if(dNewSL>0)
         { // Actualiza SL
            if(!cTrade.PositionModify(ticket,dNewSL,0))
            {
               vtext="Error en función SetLevelZeroThread al actualizar niveles en ticket "+IntegerToString(ticket)+" error:"+IntegerToString(GetLastError());
               ENUMTXT = PRINT;
               expertLog();
               return -1;
            }
            vtext="SetLevelZeroThread.Actualizado SL en ticket "+IntegerToString(ticket)+" Nuevo SL:"+DoubleToString(dNewSL);
            ENUMTXT = PRINT;
            expertLog();
         } 
      }
   }
   // Bien
   return 1;
}
// Tengo la op cargada. Es G-1. Eliminar SL/TP si procede.
short ClearTP()
{
   double dTP = 0.00;
   ulong ticket=0;
   // Check all ops
   ticket=cPos.Ticket();
   dTP=cPos.TakeProfit();
   // Si no estÃ¡ en ganancias siguiente
   if(dTP<=0) return 1;
   // Si esta en beneficios el sl no tocar
   if(bCheckSlProfit()== true) return 1;
   // Actualizar Posicion
   if(!cTrade.PositionModify(ticket,0,0))
   {
      vtext="Error al actualizar ClearTP en ticket "+IntegerToString(ticket)+" error:"+IntegerToString(GetLastError());
      ENUMTXT = PRINT;
      expertLog();
      return -1;
   }
   vtext="ClearTP aplicado en ticket G-1 "+IntegerToString(ticket)+". TP desactivado.";
   ENUMTXT = PRINT;
   expertLog();
   // Bien
   return 1;
}


//              ------------------------------------------------------------------------------------------------------------------- //
//              ----------------------------------------------- ZERO GRAVITY CODE ------------------------------------------------------ //
//              ------------------------------------------------------------------------------------------------------------------- //

// ------------------------------------------------------------------------------------------------------------------- //
// ---------------------------------------------- GREEN CODE --------------------------------------------------------- //
// ------------------------------------------------------------------------------------------------------------------- //

// Se le pasa el precio del proximo scalp y se ajusta para no estar en zonas cercanas a 0 0 a 50 pips.
double GetGreenPrice(double dNewPrice,ENUM_POSITION_TYPE TYPE_POS)
{
   // Para la mayorÃ­a de pares de divisas 1 pip es 0.00001; para pares de divisas con el Yen JaponÃ©s como EUR/JPY 1 pip es 0.001
   double dCalc=0;
   double dPipsNew=0;
   string sRighPips;
   int iPips;
   dCalc=dNewPrice;
   sRighPips=DoubleToString(dNewPrice,5);
   // Control puto YEN
   if(pips==0.001)
   {
      sRighPips=DoubleToString(dNewPrice,3);
   }
   // Hacer siempre la posiciÃ³n mÃ¡s cercana a la operaciÃ³n a finalizar (ganar menos pero asegurar).
   if(TYPE_POS==POSITION_TYPE_BUY)
   {
      dPipsNew=(iFrancisca*0.5*pips)*(-1);
   }
   else
   {
      dPipsNew=(iFrancisca*0.5*pips);
   }
   sRighPips=StringSubstr(sRighPips, StringLen(sRighPips)-2,2);
   iPips=(int)sRighPips;
   // Control de saltos
   if((iPips>46 && iPips<54) || (iPips>95 || iPips<5))
   {
      // Sumar iFrancisca
      dCalc=(dNewPrice+(dPipsNew));
   }
   // Bien
   return dCalc;
}



//              ------------------------------------------------------------------------------------------------------------------- //
//              ---------------------------------------------- GREEN CODE --------------------------------------------------------- //
//              ------------------------------------------------------------------------------------------------------------------- //



///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

///////////////////////////// NEW DEVS

///////////////////////////// DEPRECIDED FUNTIONS

// ------------------------------------------------------------------------------------------------------------------- //
// ------------------------------------------- BREAKEVENT CODE ------------------------------------------------------- //
// ------------------------------------------------------------------------------------------------------------------- //
// Se le pasa el ticket original para marcar todas las coberturas de ese ticket
short CheckBreakEventDownd()
{
   // Si no tiene SL es la superior guardarla para cuando se pueda.
   ulong lTicketProc=0;
   double ddiff = 0.00;
   double dopen =  0.00;
   double dprice = 0.00;
   double DnewTP = 0.00;
   ulong lstep=0;
   ulong sZgravityStep;
   // Coger el parámetro que ha seleccionado el usuario
   sZgravityStep=GetGravityStep();
   // Check all ops
   for(int i=0;i<9;i++) // returns los posibles hilos
   {
      // Sólo si el hilo está activo, coger la op más baja
      if(ATREND[i][0]<=0) continue;
      if(!cPos.SelectByTicket(ATREND[i][0]))
      {
         Print("Error al seleccionar orden. Error = ",GetLastError());
         return -1;
      }
      lTicketProc=cPos.Ticket();
      // Si no está en ganancias siguiente
      if(cPos.Profit()<0) continue;
      // Si esta en beneficios el sl no tocar
      if(bCheckSlProfit()== true) continue;
      lstep=GetStep(cPos.Comment());
      // Control es Gz. G-1 se considera el inicio del hilo
      if(lstep>=sZgravityStep-1) continue;
      dopen=cPos.PriceOpen();
      dprice=cPos.PriceCurrent();
      // Controlar posición en ganancias
      ddiff=MathAbs(dopen-dprice);
      if(ddiff<((TakeProfit*1.5)*pips)) continue;
      // Cerrar op
      if(!cTrade.PositionClose(lTicketProc))
      {
         vtext="Error en CheckBreakEventDown cerrar el ticket "+IntegerToString(lTicketProc)+" error:"+IntegerToString(GetLastError());
         ENUMTXT = PRINT;
         expertLog();
         return -1;
      }
      //BreakEvent realizado.
      vtext="CheckBreakEventDown aplicado en ticket "+IntegerToString(lTicketProc)+". Se ha cerrado operación.";
      ENUMTXT = PRINT;
      expertLog();
   }
   // Bien
   return 1;
}


//              ------------------------------------------------------------------------------------------------------------------- //
//              ------------------------------------------- BREAKEVENT CODE ------------------------------------------------------- //
//              ------------------------------------------------------------------------------------------------------------------- //




double GetSLStepd(ulong lstep,int ithread,datetime doldopen, ENUM_POSITION_TYPE TPOS)
{
   double dPrice=0;
   double dPips=0;
   double dTP=0;
   double dNewSL=0;
   // Obtener el precio
   dPrice=cPos.PriceOpen();
   dTP=cPos.TakeProfit();
   dPips=MathAbs(dPrice-dTP);
   //dPips+=(TakeProfit*0.5*pips); 
   dPips+=(iFrancisca*pips); 
   // Descontar los pips que se aÃ±adieron por la comision de apertura
   dPips-=(iComisionPips*pips);
   // Descontar la ganacia para operaciones > 1
   if(lstep<1)
   {
      // Calcular el SL dependiendo de la operaciÃ³n.
      if(TPOS==POSITION_TYPE_SELL)
      { 
         dNewSL=NormalizeDouble(dPrice+dPips,Digits());
      }
      // PosiciÃ³n de compras. Meter sl negativo
      else
      {
         dNewSL=NormalizeDouble(dPrice-dPips,Digits());
      }
   }
   // Calcular precio por historico de barras de hilo
   else
   {
      dNewSL=GetBarPiecesThread(doldopen,TPOS);
   }
   // Bien
   return dNewSL;
}


short GetPricesThread(int ithread)
{
   double dOpen=0;
   // INIT VALUES
   dLPRICE[ithread]=0;
   dHPRICE[ithread]=0;
   // Recorrer operaciones de hilo
   ulong ticket=0;
   dLPRICE[ithread]=-100;
   double dMinOp=1000; 
   dHPRICE[ithread]=1000;
   double dMaxOp=0;
   // El proceso siempre retorna el array de menor a mayor ticket
   for(int x=0;x<99;x++)
   {
      // Control si encuentra parar.
      if(ATREND[ithread][x]>0)
      {
         ticket=ATREND[ithread][x];
         // Cargar la posiciÃ³n
         if(!cPos.SelectByTicket(ticket))
         {
            vtext="GetPricesThread: No se ha podido cargar ticket "+IntegerToString(ticket);
            ENUMTXT = PRINT;
            expertLog(); 
            return -1;
         }
         // Get dOPEN
         dOpen=cPos.PriceOpen();
         // Cargar max/min
         if(dMinOp>dOpen) dMinOp=dOpen;
         if(dMaxOp<dOpen) dMaxOp=dOpen;
         // Control de precios. Coger los precios mÃ¡s pequeÃ±os en cada lado.
         if(cPos.PositionType()==POSITION_TYPE_SELL)
         { // Bear OPS
            if(dLPRICE[ithread]< dOpen) dLPRICE[ithread]=dOpen; 
         }
         else
         {  // BULL OPS
            if(dHPRICE[ithread] > dOpen) dHPRICE[ithread]=dOpen; 
         }    
      }
      else
      {
         // Exist for
         x=99;
      }
   }
   // Bien
   return 1;
}
short CheckHighBreakd(double dNewLot)
{
   double dHighLot = (Lots * iCent *50);
   datetime dAhora=TimeCurrent();
   MqlDateTime strdate;
   TimeToStruct(dAhora,strdate);
   // Si es lote bajo dejar abrir
   if (dNewLot<dHighLot) return 1;
   // Si es jueves o viernes esperar a apertura Wall Street
   ///////////////////////////////////////////////if (strdate.day_of_week < 4 ) return 0;
   // // Wall Street open 15:30
   if(strdate.hour>14 && strdate.min > 30) 
   {
      vtext="Apertura Wall Street confirmada.BreakZero activada.";
      ENUMTXT = PRINT;
      expertLog();
      return 1; 
   }
   // Por defecto no puede abrir
   return 0;
}
