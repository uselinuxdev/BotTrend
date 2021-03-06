//+------------------------------------------------------------------+
//|                                                     BotTrend.mq5 |
//|                                    Copyright 2019, Usefilm Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2020, Usefilm Corp."
#property link      "https://www.mql5.com"
#define VERSION "2.24"
#property version VERSION

// Inclusión de objetos de liberia estandar
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
   SUMMER_TIME,
   CHRISTMAS
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

// CONTROL POR TIEMPO
datetime timeCurent;
datetime timeCheck;

//--- Global vars
//+------------------------------------------------------------------+
//| Expert MAGIC number                                              |
//+------------------------------------------------------------------+
#define MAGICTREND 13330
string BOTNAME="TRENDBOT "+VERSION;
long ATRENDBOT[];
long ATRENDMAX[];
long ATRENDCOUNT[]; 

MqlRates rLastBars[],rCurrent[];
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
input ENUM_TIMEFRAMES botperiod=PERIOD_M5;
input int      iMaxSpread=5;
input double   TakeProfit=60;
input bool     bdoubleLot1806=false;
// input double   dComisionLot= 2.75; // IC MARKETS
input double   dImpThreadClose=2;
input double   dComisionLot=0;
int iComisionPips=0;
input double   dNextBuyStep=0;
input double   dNextSellStep=0;
input int      piNumBars=3;
input int      iMaxThead=1;
input bool     bSoftFriday=true;
input bool     bHollidays=true;
input ulong    lMaxHighTrend=6;
input ENUM_CENT ENUMCENT=CENT_1;

// Dont open when the market will be to close. Or opened 1h.
int iHilos=0;
double dLotBear=0.0;
double dLotBULL=0.0;
double dCommision=0.0;
double dSwapAll=0.0;
double dNextScalp=0.0;
// Control de grandes hilos aperturas escalonadas
datetime FreezeTime;
input short saddhour=3;
ENUM_ORDER_TYPE ENUMBARDIR;
double Lots = 0.01;
/////////////////////////////double dAccountEquity = 0.00;
int    lotdecimal = 2; 
//////////// Manejadores de media
int iHandlelow,iHandleMed,iHandleHigh=0;
double mabot[3];

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
   timeCheck=TimeCurrent()+120;
   FreezeTime=TimeCurrent();
   countbot(); 
   // Licence code
   LoadLicenceAccount();
   // Primer check de licences
   if(CheckLicence()==0) return -1;
   //--- create application dialog. Si falla da igual, continuar
   if(ExtDialog.Create(0,"BotTrend Panel version: "+VERSION,0,40,40,400,240))
   {
      //--- run application
      ExtDialog.Run();
   }
   // Crear manejadores de media
   if(CreateHandleMed()==false)
   {
      return(INIT_FAILED);
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
//---
   // Check period with input value
   timeCurent = TimeCurrent();
   if(Period()!= botperiod)
   {
         vtext="El perido es diferente al seleccionado en el robot : "+EnumToString(botperiod)+"!="+EnumToString(Period())+". Robot parado durante 30 segundos.";
         ENUMTXT = ALERT;
         expertLog();
         // Wait 30 second
         Sleep(30000);
         return;
   }
   // Sólo refrescar 1 vez lo Rates por Tick
   // Coger últimas barras
   GetLastBar();
   // Ajustar cent
   GetCent();
   // Contar ops.
   if(countbot()<0) return;
   // Every ticks Check Franciscada
   if(goFrancisca()<0) return;
   // Comprobar cada 1min.
   if(timeCheck<timeCurent)
   {
      timeCheck = TimeCurrent()+60;
      // Comprobar Hilo
      if(CheckEquality()<0) return;
      // Igualar SL y TP de todos los hilos
      // Check for new steps
      if(CheckNewStep()<0) return;
      // SL
      if(SetSLMax()<0) return;
      // Actualiza panel
      RefressPanel();
   }
   //--- go trading only for first ticks of new bar. Actual bar is the last array element
   if(rCurrent[0].tick_volume==1)
   {
      enumbotmode=WORKING_DAY;
      // Open new positions
      if(MarketClosing()==0) return;
      if(BotVacation()==0) return;
      CheckForOpen();
      //HIGHTRENDBOT
      OpenHighTrend();
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
   ALOGINGOLD[0]=5141012;
   ALOGINGOLD[1]=50165336;    /// DEMO ACCOUNT
   ALOGINGOLD[2]=781805;    /// DEMO ACCOUNT VANTAGE
   // Client accounts
   // Miguel Bayon IC
   ALOGINGOLD[3]=50377716;
   // Carlos demo Account
   ALOGINGOLD[4]=781217; 
   // Miguel Demo Vantage
   ALOGINGOLD[5]=781025;
   // Cuenta DAVID (Sólo robot)
   ALOGINGOLD[6]=784357;
     
   /////////////////////////////////////////////////////////////////////////////////////////
   // Silver licences. Posición igual Nº de cuenta y fecha
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
   ALOGINSILVER[1]=68014701; 
   // Fecha fin Carlos
   MQDATELOGIN[1].day=15;
   MQDATELOGIN[1].mon=1;
   MQDATELOGIN[1].year=2021;
   // Cuenta Carlos Inversores
   ALOGINSILVER[2]=68017236;
   // Fecha fin Carlos Inversores
   MQDATELOGIN[2].day=15;
   MQDATELOGIN[2].mon=01;
   MQDATELOGIN[2].year=2021;   
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
   // Buscar licencia por suscripción
   for(int i=0;i<ArrayRange(ALOGINSILVER,0);i++)
   {
      if(ALOGINSILVER[i]==laccount)
      {
         vtext="Bot ha encontrado una licencia Silver para la cuenta:"+IntegerToString(laccount)+" - "+Cacc.Name();
         ENUMTXT = PRINT;
         expertLog();
         printf("Licencia válida hasta el %02d/%02d/%4d",MQDATELOGIN[i].day,MQDATELOGIN[i].mon,MQDATELOGIN[i].year,".");
         enumlicence=SILVER;
         return 1;
      }
   }   
   vtext="La cuenta "+IntegerToString(laccount)+" no se encuentra licenciada.Último aviso, PAGA LA DROGA!";
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
   // Buscar licencia por suscripción
   for(int i=0;i<ArrayRange(ALOGINSILVER,0);i++)
   {
      if(ALOGINSILVER[i]==laccount)
      {
         // Posición de cuenta en i
         if(MQDATELOGIN[i].year<=strdate.year && MQDATELOGIN[i].mon<=strdate.mon && MQDATELOGIN[i].day<strdate.day)
         {
            vtext="La cuenta "+IntegerToString(laccount)+" ha finalizado su perido de suscripción.Renueve su licencia!!!.";
            ENUMTXT = PRINT;
            expertLog();
            printf("La licencia finalizó el %02d/%02d/%4d",MQDATELOGIN[i].day,MQDATELOGIN[i].mon,MQDATELOGIN[i].year,".");
            return 0;
         }
         // La licencia poner el último día válido
         if(MQDATELOGIN[i].year==strdate.year && MQDATELOGIN[i].mon==strdate.mon && MQDATELOGIN[i].day+7>strdate.day)
         {
            vtext="La cuenta "+IntegerToString(laccount)+" finaliza su suscripción en menos de 7 días.";
            ENUMTXT = PRINT;
            expertLog();
            printf("La licencia finalizará el %02d/%02d/%4d",MQDATELOGIN[i].day,MQDATELOGIN[i].mon,MQDATELOGIN[i].year,".");
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

// ------------------------------------------------------------------------------------------------------------------- //
//                                                Moving Average indicators                                            //
// ------------------------------------------------------------------------------------------------------------------- //
// Crea los manejadores de medias (low, medium and high iMA)
bool CreateHandleMed()
{
   // Valores de medias low,med,high
   int iLow=20;
   int iMed=60;
   int iHigh=200;
   // Crear media low. Desplazamiento las iRow que se evaluan. Media simple al precio de cierre
   iHandlelow=iMA(_Symbol,_Period,iLow,piNumBars,MODE_SMA,PRICE_CLOSE);
   if(iHandlelow==INVALID_HANDLE)
   {
      vtext="Error al crear MA pequeña.";
      ENUMTXT = ALERT;
      expertLog();
      return(false);
   }
   /// TEST
   // Crear iMA mediata
   iHandleMed=iMA(_Symbol,_Period,iMed,piNumBars,MODE_SMA,PRICE_CLOSE);
   if(iHandleMed==INVALID_HANDLE)
   {
      vtext="Error al crear MA mediana.";
      ENUMTXT = ALERT;
      expertLog();
      return(false);
   }
   // Crear iMA grande
   iHandleHigh=iMA(_Symbol,_Period,iHigh,piNumBars,MODE_SMA,PRICE_CLOSE);
   if(iHandleHigh==INVALID_HANDLE)
   {
      vtext="Error al crear MA mayor.";
      ENUMTXT = ALERT;
      expertLog();
      return(false);
   }
   // Bien
   return true;
}
// Actualizar buffer de medias móviles
int RefreshMa()
{
   double   ma[1];
   // Get Malow
   if(CopyBuffer(iHandlelow,0,0,1,ma)!=1)
   {
      vtext="Error al cargar el buffer de media móvil low.";
      ENUMTXT = ALERT;
      expertLog();
      return -1;
   }
   mabot[0]=ma[0];
   // Get MaMed
   if(CopyBuffer(iHandleMed,0,0,1,ma)!=1)
   {
      vtext="Error al cargar el buffer de media móvil media.";
      ENUMTXT = ALERT;
      expertLog();
      return -1;
   }
   mabot[1]=ma[0];
   // Get MaHigh
   if(CopyBuffer(iHandleHigh,0,0,1,ma)!=1)
   {
      vtext="Error al cargar el buffer de media móvil High.";
      ENUMTXT = ALERT;
      expertLog();
      return -1;
   }
   mabot[2]=ma[0];    
   // Bien
   return 1;
}

// ------------------------------------------------------------------------------------------------------------------- //
//                                                Moving Average indicators END                                        //
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
void GetLastBar()
{
   SymbolInfo.Name(_Symbol);
   SymbolInfo.Refresh();
   SymbolInfo.RefreshRates();
   int copied=CopyRates(Symbol(),0,1,piNumBars,rLastBars);
   if(copied<piNumBars)
   {
      vtext="El copiado de datos historicos de "+_Symbol+" ha fallado, historial no disponible.";
      ENUMTXT = ALERT;
      expertLog();
      return;
   }
   CopyRates(Symbol(),0,0,1,rCurrent); 
}
// La funcion retorna si el Nº mágico es de los del bot.2 Si es un TBOT
short IsMyMagic(long lMagicCheck)
{
   vtext = "Check Nº magico:"+IntegerToString(lMagicCheck);
   ENUMTXT = PRINT;
   //expertLog();
   if(lMagicCheck >=MAGICTREND && lMagicCheck<=MAGICTREND+9) return 1;
   // No es de los nuestros
   return 0;
}

// Función de actualización de datos del panel
void RefressPanel()
{
  ExtDialog.UpdatePannel(EnumToString(enumbotmode),dLotBULL,dLotBear,iHilos,EnumToString(enumthread),dCommision,dSwapAll,dNextScalp);
}


void checkBardir()
{
   // Declarations and rest values.
   ENUMBARDIR = WRONG_VALUE;
   ENUMTXT = PRINT;
   vtext="";
   //vtext = "Comprobando tendencia de los últimos "+IntegerToString(piNumBars)+" periodos.";
   //expertLog();
   // Recorrer las Nvelas desde la posicion anterior a la actual 0
   // Check tendence: iPopen 0 is the actual bar
   if(iOpen(NULL,PERIOD_CURRENT,0)< iOpen(NULL,PERIOD_CURRENT,piNumBars))
   {
      vtext = "Detectada tendencia BEAR (SELL).Usando tendecia.";
      ENUMBARDIR = ORDER_TYPE_SELL;
   }
   else
   {
      vtext = "Detectada tendencia BULL (BUY).Usando tendecia.";
      ENUMBARDIR = ORDER_TYPE_BUY;
   }
  // Print check result
  expertLog();  
}

/// Cálculo comisión por lote. De las posición cargada. El importe es negativo
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

/////////////////////////////////////////////// Contar bots. MAX 9 hilos
short countbot()
{
   int ipos=0; 
   // La funcion cuenta los bot que estan abiertos actualmente. Resetea el array con 0 
   ArrayResize(ATRENDBOT,9);
   ArrayFill(ATRENDBOT,0,9,0);
   ArrayResize(ATRENDMAX,9);
   ArrayFill(ATRENDMAX,0,9,0);
   // Contar las operaciones por hilo
   ArrayResize(ATRENDCOUNT,9);
   ArrayFill(ATRENDCOUNT,0,9,0);
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
      if(IsMyMagic(cPos.Magic()))
      {
         ticket=cPos.Ticket();
         // Seleccionar deal
         ipos=(int)(cPos.Magic()-MAGICTREND);
         // Calculo de comisión: Tamaño del lote * Importe de la comisión * 2(Apertura y cierre).
         dCommision+=getComisionPos();
         dSwapAll+=cPos.Swap();
         if(cPos.PositionType()==POSITION_TYPE_SELL)
         {
            dLotBear+=cPos.Volume();
         }
         else
         {
            dLotBULL+=cPos.Volume();
         }
         ATRENDBOT[ipos]=cPos.Magic();
         if(ATRENDMAX[ipos]<cPos.Identifier())
         {
            ATRENDMAX[ipos]=cPos.Identifier();
         }
         // Contar por hilo
         ATRENDCOUNT[ipos]+=1;
      }
   }
   /////////////////////////////////////
   return 1;
}

void CheckForOpen()
{
   int ifreepos=0;
   double TP0=0.0;
   double dLotOpen=Lots;
   double dCommOpen=0.0;
   double dAddSpread=0.00;
   string scoment="";
   //Doble lote en horas de baja actividad
   datetime dNow=TimeCurrent();
   MqlDateTime strdate;
   //Recalc CENT
   dLotOpen=dLotOpen*iCent;

// Si hay mucho movimiento salirse
   if(iMaxSpread < SymbolInfo.Spread())
   {
      vtext="El Spread actual "+IntegerToString(SymbolInfo.Spread())+" es superior al máximo configurado en el robot.";
      ENUMTXT = PRINT;
      expertLog();
      return;   
   }
//--- additional checking
   if(TerminalInfoInteger(TERMINAL_TRADE_ALLOWED))
   {
      // Control de licencias por suscripción
      if(CheckSilverEnd()==0) return;
      // Actualizar valor de la cuenta
      //////////////////////////////GetEquity();
      // Tipo de tendencia
      // Obtener posicion de array disponible
      ifreepos=GetFreePos();
      if (ifreepos < 0)
      {
         vtext="No se ha creado una nueva orden al haber llegado al máximo de hilos.";
         ///expertLog();   // Texto pintado en funcion GetFreePos
         return;  
      }
      // Pintar tendencia. Sólo cuando se va a abrir
      // Bar is new  
      checkBardir();
      // Control doble lote
      // Controlar doble lote
      TimeToStruct(dNow,strdate);
      if(bdoubleLot1806==true && (strdate.hour>18 || strdate.hour<6))
      {
         dLotOpen=Lots*iCent*2;
         vtext="Doble lote activado 18pm-6am.";
         ENUMTXT = PRINT;
         expertLog();
      }
      // Peso del Spread añadir al SL
      dAddSpread=MathAbs(SymbolInfo.Bid()-SymbolInfo.Ask());
      if(dAddSpread>(iFrancisca*pips)) dAddSpread=iFrancisca*pips;
      // Control de comisión
      dCommOpen+=iComisionPips;
      switch(ENUMBARDIR)
      {
         case ORDER_TYPE_SELL:
            // Asignar el numero mágico de ventas   
            cTrade.SetExpertMagicNumber(ATRENDBOT[ifreepos]);
            // Control de SWAP
            if(SymbolInfo.SwapShort()<0)dCommOpen+=4;
            TP0=SymbolInfo.Bid()-(TakeProfit*pips)-(dCommOpen*pips)-dAddSpread;
            scoment=BOTNAME+" ("+IntegerToString(ATRENDBOT[ifreepos])+") step: 0";
            if(!cTrade.Sell(dLotOpen,_Symbol,0,0,TP0,scoment))
            {
               vtext="Se ha producido el error "+IntegerToString(GetLastError())+" al abrir una operación de "+DoubleToString(Lots)+".";
               ENUMTXT = PRINT;
               expertLog();
            }
            return;
            break;  
         case ORDER_TYPE_BUY:
            // Asignar el numero mágico de ventas
            cTrade.SetExpertMagicNumber(ATRENDBOT[ifreepos]);
            // Control de SWAP
            if(SymbolInfo.SwapLong()<0)dCommOpen+=4;
            TP0=SymbolInfo.Ask()+(TakeProfit*pips)+(dCommOpen*pips)+dAddSpread;
            scoment=BOTNAME+" ("+IntegerToString(ATRENDBOT[ifreepos])+") step: 0";
            if(!cTrade.Buy(dLotOpen,_Symbol,0,0,TP0,scoment))
            {
               vtext="Se ha producido el error "+IntegerToString(GetLastError())+" al abrir una operación de "+DoubleToString(Lots)+".";
               ENUMTXT = PRINT;
               expertLog();
            }
            return; 
            break;
      }           
   }
}

// Obtener una posicion libre en el array
int GetFreePos()
{  
   // Evaluar cuenta para Nº de hilos MAX 9. Cada 1500 1 hilo
   double dEquity=0;
   iHilos=0;
   datetime dNow=TimeCurrent();
   MqlDateTime strdate;
   
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
         expertLog();
         return i;
      }
   }
   return -1;
}
// No operar en navidad ni el 1 de agosto (+- 7 días).
short BotVacation()
{
   datetime dNow=TimeCurrent();
   MqlDateTime strdate;
   // Si esta desactivado ok
   if(!bHollidays) return 1;
   // Esta activado
   TimeToStruct(dNow,strdate);
   // Si es navidad
   if((strdate.mon==12 && strdate.day>19) || (strdate.mon==1 && strdate.day<6) )
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
         vtext="Desactivada la creación de nuevas operaciones en la primera hora de apertura de mercado.";
         ENUMTXT = PRINT;
         expertLog();
      }
      return 0;
   }
   // Control último día de la semana de forex
   if(bSoftFriday==true)
   {
      if(strdate.day_of_week<4) return 1;
      // Control jueves tarde / noche
      if(strdate.day_of_week==4 && (strdate.hour+saddhour)<23) return 1; 
      if(strdate.min==0)
      {
         vtext="Último día de mercado con parámetro de nuevas operaciones desactivado bSoftFriday.";
         ENUMTXT = PRINT;
         expertLog();
      }
      enumthread=ISFRIDAY;
      enumbotmode=SOFT_FRIDAY;
      return 0;      
   } 
   return 1;
}

ulong GetStep()
{
   ulong lstep=0;
   string scoment="";
   // Coger scoment
   scoment=StringSubstr(cPos.Comment(), (StringLen(cPos.Comment())-2));
   StringTrimLeft(scoment);
   lstep=StringToInteger(scoment);
   return lstep;
}

// ------------------------------------------------------------------------------------------------------------------- //
// ------------------------------------------- MATRINGALA2 CODE ------------------------------------------------------ //
// ------------------------------------------------------------------------------------------------------------------- //

// Comprueba si una operación esta en perdidas y llama a la función NewStep
int CheckNewStep()
{
   ulong lTicket=0;
   double dpricestep=0.0;
   double dnewprice=0.0;
   double dAddSpread=0.0;
   double dTP=0.0;
   double dNewTP=0.0;
   double dSL=0.0;
   double LotStep=0.00;
   double dCommOpen=0;
   double dHandicap=0;
   ulong lstep=0;
   string scoment=""; 
   // No saturar el alert del bot
   datetime dNow=TimeCurrent();
   // Controlar si esta en FrezzeTime
   if(dNow<FreezeTime)
   {
      vtext="Freeze detectado por SLMax. El bot no abrirá nuevos saltos hasta "+TimeToString(FreezeTime)+".";
      ENUMTXT = PRINT;
      expertLog();
      return 0;   
   }
   MqlDateTime strdate;
   TimeToStruct(dNow,strdate);
   // Si hay mucho movimiento salirse
   if(iMaxSpread < SymbolInfo.Spread())
   {
      vtext="El Spread actual "+IntegerToString(SymbolInfo.Spread())+" es superior al máximo configurado en el robot.";
      ENUMTXT = PRINT;
      expertLog();
      return 0;   
   }
   // Control de  comisión
   dCommOpen+=(iComisionPips*pips);
   ENUM_POSITION_TYPE TYPE_POS=POSITION_TYPE_BUY;
   for(int i=0;i<PositionsTotal();i++) // returns the number of current positions
   {
      if(!cPos.SelectByIndex(i))
      {
         Print("Error al seleccionar orden. Error = ",GetLastError());
         return -1;
      }
      if(_Symbol!=cPos.Symbol()) continue;
      // Si tiene SL y TP siguiente
      if(cPos.TakeProfit()>0 && cPos.StopLoss()>0) continue;
      // Check Bot
      if(IsMyMagic(cPos.Magic()))
      {
         TYPE_POS=cPos.PositionType();
         lTicket = cPos.Ticket();
         dpricestep = cPos.PriceOpen();
         lstep=GetStep();
         lstep+=1;
         LotStep=NormalizeDouble(((cPos.Volume()*2)+(Lots*iCent)), lotdecimal); 
         scoment=BOTNAME+" ("+IntegerToString(cPos.Magic())+") step: "+IntegerToString(lstep);
         // Control de HBOT
         if(StringSubstr(cPos.Comment(), 0,1)=="H")
         {
            scoment="H"+scoment;
         } 
         dAddSpread=MathAbs(SymbolInfo.Ask()-SymbolInfo.Bid());
         // Dependiendo tipo de posición
         if(TYPE_POS==POSITION_TYPE_SELL)
         {
            // Original Venta
            dTP=cPos.TakeProfit();
            dnewprice=NormalizeDouble(SymbolInfo.Bid(),Digits());
            dNextScalp=MathAbs(dpricestep-dTP);
            // Quitar ifrancisca para nueva apertura
            dNextScalp=NormalizeDouble(dpricestep+dNextScalp,Digits());
            // Descontar swap posición anterior de op sell. En test hay mermas ... no activar
            /////////////////////////////////////////////////////////////////////////////////if(SymbolInfo.SwapShort()<0)dCommOpen+=(4*pips);
            // NO ACTIVAR
            // Descontar la comisión de apertura abrir nuevo step
            dNextScalp-=dCommOpen;
            // Control de lstep quitar beneficio paso previo
            if(lstep>1) 
            {
               dNextScalp-=(iFrancisca*2.5*pips);
            }
            
            if(lstep<4)
            {
               dNextScalp+=NormalizeDouble((TakeProfit*0.5*pips),Digits());
            }
            if(lstep>3) 
            {
               // Check IA BOT
               if(dNextBuyStep==0)
               { 
                  dHandicap=CalcHighLotNext(TYPE_POS);
                  if(dHandicap==-1) return -1;
                  dNextScalp+=NormalizeDouble(dHandicap,Digits());
                  vtext="Control de grandes lotes. Precio de siguiente BUY calculado por Bot:"+DoubleToString(dNextScalp);
                  ENUMTXT = PRINT;
               }
               if(dNextBuyStep>0)
               { 
                  dNextScalp=dNextBuyStep;
                  vtext="Control de grandes lotes. Precio de siguiente BUY definido por usuario, dNextBuyStep:"+DoubleToString(dNextScalp);
                  ENUMTXT = PRINT;
                  
               }
               // Sólo pintar cada 15 min
               if(strdate.min==0 || strdate.min==15 || strdate.min==30 || strdate.min==45)
               {
                  expertLog();
               }          
            }
            // Si el precio se ha ido encontra mas del TP
            if(dnewprice>dNextScalp)
            {
               // 1 Generar nueva posción en dir contraria
               dNewTP=MathAbs(dpricestep-dnewprice);
               dNewTP=NormalizeDouble(dnewprice+dNewTP+dCommOpen+(iFrancisca*2.5*pips),Digits());
               dSL=NewStep(dNewTP,LotStep,scoment,POSITION_TYPE_BUY);
               // Continue si NewStep es 0
               if(dSL==0) continue;
               dSL=NormalizeDouble(dSL-(iFrancisca*pips),Digits());
               // Añadir el spread actual a la posición vieja SELL
               dSL=NormalizeDouble(dSL+dAddSpread,Digits());
               if(dSL>dNewTP) dSL=dNewTP;
               // 2 Poner SL de posición con problemas
               if(!cTrade.PositionModify(lTicket,dSL,dTP))
               {
                  vtext="Error al actualizar Franciscada en ticket "+IntegerToString(cPos.Ticket())+" error:"+IntegerToString(GetLastError());
                  ENUMTXT = PRINT;
                  expertLog();
                  return -1;
               }
               // Contar ops.
               if(countbot()<0) return -1;
            }
         }
         else
         {
            // Original Compra
            dTP=cPos.TakeProfit();
            dnewprice=NormalizeDouble(SymbolInfo.Ask(),Digits());
            dNextScalp=MathAbs(dpricestep-dTP);
            dNextScalp=NormalizeDouble(dpricestep-dNextScalp,Digits());
            // Descontar swap posición anterior de op BUY.... En test hay mermas. No activar
            ////////////////////////////////////////////////////////////////////7//if(SymbolInfo.SwapLong()<0)dCommOpen+=(4*pips);
            // NO ACTIVAR
            // Descontar la comisión de apertura abrir nuevo step
            dNextScalp+=dCommOpen;
            // Control de lstep quitar beneficio paso previo
            if(lstep>1) 
            {
               dNextScalp+=(iFrancisca*2.5*pips);
            }
            if(lstep<4) 
            {
               dNextScalp-=NormalizeDouble((TakeProfit*0.5*pips),Digits());
            }
            if(lstep>3) 
            {
               // Check IA BOT
               if(dNextSellStep==0)
               { 
                  dHandicap=CalcHighLotNext(TYPE_POS);
                  if(dHandicap==-1) return -1;
                  dNextScalp-=NormalizeDouble(dHandicap,Digits());     
                  vtext="Control de grandes lotes. Precio de siguiente SELL calculado por Bot:"+DoubleToString(dNextScalp);
                  ENUMTXT = PRINT;
               }
               if(dNextSellStep>0)
               { 
                  dNextScalp=dNextSellStep;
                  vtext="Control de grandes lotes. Precio de siguiente SELL definido por usuario, dNextSellStep:"+DoubleToString(dNextScalp);
                  ENUMTXT = PRINT;
               }
               // Sólo pintar cada 15 min
               if(strdate.min==0 || strdate.min==15 || strdate.min==30 || strdate.min==45)
               {
                  expertLog();
               }    
            }  
            // Si el precio se ha ido encontra mas del TP
            if(dnewprice<dNextScalp)
            {
               // 1 Generar nueva posción
               dNewTP=MathAbs(dpricestep-dnewprice);
               dNewTP=NormalizeDouble(dnewprice-dNewTP-dCommOpen-(iFrancisca*2.5*pips),Digits());
               dSL=NewStep(dNewTP,LotStep,scoment,POSITION_TYPE_SELL);
               // Continue si NewStep es 0
               if(dSL==0) continue;
               dSL=NormalizeDouble(dSL+(iFrancisca*pips),Digits());
               // Añadir el spread actual a la pos vieja buy
               dSL=NormalizeDouble(dSL-dAddSpread,Digits());
               if(dSL<dNewTP) dSL=dNewTP;
               // 2 Poner SL de posición con problemas
               if(!cTrade.PositionModify(lTicket,dSL,dTP))
               {
                  vtext="Error al actualizar Franciscada en ticket "+IntegerToString(cPos.Ticket())+" error:"+IntegerToString(GetLastError());
                  ENUMTXT = PRINT;
                  expertLog();
                  return -1;
               }
               // Contar ops.
               if(countbot()<0) return -1;
            }            
         }
      }      
   }
   // Bien
   return 1;
}

double NewStep(double newTP,double LotStep,string scoment,ENUM_POSITION_TYPE TYPE_POS)
{
   ulong lMagic=0;
   double dSwap=0.0;
   double dTP = 0.00;
   
   // Asignar el numero mágico de ventas   
   cTrade.SetExpertMagicNumber(cPos.Magic()); 
   switch(TYPE_POS)
   {
      case POSITION_TYPE_SELL:
         // Control de SWAP
         if(SymbolInfo.SwapShort()<0)dSwap=4;
         dTP=newTP-(dSwap*pips);
         if(!cTrade.Sell(LotStep,_Symbol,0,0,dTP,scoment))
         {
            vtext="Se ha producido el error "+IntegerToString(GetLastError())+" al abrir una operación de "+DoubleToString(LotStep)+".";
            ENUMTXT = PRINT;
            expertLog();
            return -1;
         }
         break;  
      case POSITION_TYPE_BUY:
         // Control de SWAP
         if(SymbolInfo.SwapLong()<0)dSwap=4;
         dTP=newTP+(dSwap*pips);
         if(!cTrade.Buy(LotStep,_Symbol,0,0,dTP,scoment))
         {
            vtext="Se ha producido el error "+IntegerToString(GetLastError())+" al abrir una operación de "+DoubleToString(LotStep)+".";
            ENUMTXT = PRINT;
            expertLog();
            return -1;
         }
         break;
   }
   vtext=scoment+".Tamaño lote:"+DoubleToString(LotStep)+".";
   ENUMTXT = PRINT;
   expertLog();
   // Bien
   return dTP;
}

// Calc highLotNext
double CalcHighLotNext(ENUM_POSITION_TYPE OLDPOS)
{
   // dpricescalp ya está calculado
   int icontma=0;
   double dPrice=0; // Saber si el precio de la posición esta por encima o por debajo de las medias
   double dHandicap=0;
   // Coger últimas medias movidadas iNumbars (posición dentro de x barras)
   if(RefreshMa()<0)
   {
      return -1;
   }  
   // En cPos está el ticket que se quiere obtener el siguiente step
   dPrice=cPos.PriceCurrent();
   // Añadir handicap en relación con las medias. Si las medias están por debajo tendencia BUY si están por encima tendencia SELL.
   // Sólo comprobar media low y media intermedia
   for(int i=0;i<ArraySize(mabot)-1;i++)
   {
      if(dPrice>mabot[i])
      {
         icontma+=1;
         vtext="Media dirección BUY.";
         
      }
      else
      {
         vtext="Media dirección SELL.";
         icontma-=1;
      }
   }
   // Si la dirección de las medias se ha anulado coger la media mayor para desempatar
   if(icontma==0)
   {
      if(dPrice>mabot[piNumBars-1])
      {
         icontma+=1;
         vtext="Media dirección BUY.";
         
      }
      else
      {
         vtext="Media dirección SELL.";
         icontma-=1;
      }
   }
   ENUMTXT = PRINT;
   //expertLog(); 
   // Ver si la siguiente posición es con tendencia de las medias o encontra. Si es encontra añadir penalización
   switch(OLDPOS)
   {
      case POSITION_TYPE_SELL:
         // Si la antigua posición es SELL y la dirección de las medias es SELL añadir handicap al proximo buy
         if(icontma<0)
         {
            dHandicap=(TakeProfit*0.5*pips);
         }
         break;  
      case POSITION_TYPE_BUY:
         // Si la antigua posición es BUY y la dirección de las medias es BUY añadir handicap al proximo buy
         if(icontma>0)
         {
            dHandicap=(-1*(TakeProfit*0.5*pips));
         }
         break;
   }
   // Bien
   return dHandicap;
}

//              ------------------------------------------------------------------------------------------------------------------- //
//              ------------------------------------------- MATRINGALA2 CODE ------------------------------------------------------ //
//              ------------------------------------------------------------------------------------------------------------------- //

// ------------------------------------------------------------------------------------------------------------------- //
// ------------------------------------------- HIGHTRENDBOT CODE ------------------------------------------------------ //
// ------------------------------------------------------------------------------------------------------------------- //
// Check last bars and return Order type if there are high market moviment. More than (3*TP/2)
ENUM_POSITION_TYPE CheckHighTrend()
{
   ENUM_POSITION_TYPE TYPE_POS=WRONG_VALUE;
   // Check last bars
   int icont=0;
   // Almenos 2TP de dirección
   ///if(MathAbs(rLastBars[0].open-rLastBars[ArraySize(rLastBars)-1].close)<(TakeProfit*2*pips))
	///{
	 ///  vtext="Tamaño de la barras menor TP * 2";
	///   return TYPE_POS;
	///}
   for(int i=0;i<ArraySize(rLastBars);i++)
   {
   	// Check si es menor 50%
   	if(MathAbs(rLastBars[i].open-rLastBars[i].close)<(TakeProfit*0.5*pips))
   	{
   	   vtext="Tamaño de la barra menor al 50% del TP";
   	   return TYPE_POS;
   	}
   	if(rLastBars[i].open>rLastBars[i].close)
   	{
   	   icont-=1;
   	}
   	else
   	{
   	   icont+=1;
   	}
   }
   // Controlar si es BULL o BEAR
   if(icont>ArraySize(rLastBars)-1)
   {
      TYPE_POS=POSITION_TYPE_BUY;
   }
   if(icont<ArraySize(rLastBars)-1)
   {
      TYPE_POS=POSITION_TYPE_SELL;
   }
   //Return value
   return TYPE_POS;
}

bool ActivateHighTrend()
{
   bool bactivate=false;
   ulong lstep=0;

   // Controlar máximo salto permitido
   if(!cPos.SelectByTicket(ATRENDMAX[iMaxThead-1]))
   {
      vtext="Error en ActivateHighTrend al seleccionar ticket "+IntegerToString(ATRENDMAX[iMaxThead-1])+" : "+IntegerToString(GetLastError());
      ENUMTXT = PRINT;
      expertLog();
      return bactivate;
   }
   // Control de variable
   lstep=GetStep();
   if(lstep>lMaxHighTrend)
   {
      vtext="Desactivada apertura HighTrend. Salto actual:"+IntegerToString(lstep);
      ENUMTXT = PRINT;
      expertLog();      
      return bactivate;
   }
   // Confirmar que el hilo máximo está ocupado
   if(ATRENDBOT[iMaxThead-1]==0)
   {              
      vtext="Aun existen hilos disponibles.";
      ENUMTXT = PRINT;
      //expertLog();
      return bactivate;
   }
   // Confirmar que el hilo HighTrend no esta ocupado
   if(ATRENDBOT[iMaxThead]!=0)
   {              
      vtext="HighTrend ya fue activado.";
      ENUMTXT = PRINT;
      //expertLog();
      return bactivate;
   }   
   // Return
   bactivate=true;
   return bactivate;
}

void OpenHighTrend()
{
   double TP0=0.0;
   ulong lmaxstep=0;
   double dLotOpen=Lots;
   double dCommOpen=0.0;
   double dAddSpread=0.00;
   string scoment="";
   //Recalc CENT
   dLotOpen=dLotOpen*iCent;
   ENUM_POSITION_TYPE TYPE_POS=WRONG_VALUE;
// Si hay mucho movimiento salirse
   if(iMaxSpread < SymbolInfo.Spread())
   {
      vtext="El Spread actual "+IntegerToString(SymbolInfo.Spread())+" es superior al máximo configurado en el robot.";
      ENUMTXT = PRINT;
      expertLog();
      return;   
   } 
   // Comprobar si se puede abrir.
   if(ActivateHighTrend()==false)
   {
      return;
   }
   TYPE_POS=CheckHighTrend();
   if(TYPE_POS==WRONG_VALUE)
   {
	  vtext="La dirección del mercado es insuficiente para crear HIGHTRENDBOT.";
      ENUMTXT = PRINT;
      //expertLog();
      return;   
   }
//--- additional checking
   if(TerminalInfoInteger(TERMINAL_TRADE_ALLOWED))
   {
      // Control de licencias por suscripción
      if(CheckSilverEnd()==0) return;
      // Control maximo de hilos
      
      // Añadir hilo adicional. El máximo de parámetro +1.
      ATRENDBOT[iMaxThead]=MAGICTREND+iMaxThead;
      
      // Peso del Spread añadir al SL
      dAddSpread=MathAbs(SymbolInfo.Bid()-SymbolInfo.Ask());
      if(dAddSpread>(iFrancisca*pips)) dAddSpread=iFrancisca*pips;
      // Control de comisión
      dCommOpen+=iComisionPips;
	  // Asignar el numero mágico
      cTrade.SetExpertMagicNumber(ATRENDBOT[iMaxThead]);
      switch(TYPE_POS)
      {
         case POSITION_TYPE_SELL:
            // Control de SWAP
            if(SymbolInfo.SwapShort()<0)dCommOpen+=4;
            TP0=SymbolInfo.Bid()-(TakeProfit*pips)-(dCommOpen*pips)-dAddSpread;
            scoment="H"+BOTNAME+" ("+IntegerToString(ATRENDBOT[iMaxThead])+") step: 0";
            if(!cTrade.Sell(dLotOpen,_Symbol,0,0,TP0,scoment))
            {
               vtext="Se ha producido el error "+IntegerToString(GetLastError())+" al abrir una operación de "+DoubleToString(Lots)+".";
               ENUMTXT = PRINT;
               expertLog();
            }
            break;  
         case POSITION_TYPE_BUY:
            // Control de SWAP
            if(SymbolInfo.SwapLong()<0)dCommOpen+=4;
            TP0=SymbolInfo.Ask()+(TakeProfit*pips)+(dCommOpen*pips)+dAddSpread;
            scoment="H"+BOTNAME+" ("+IntegerToString(ATRENDBOT[iMaxThead])+") step: 0";
            if(!cTrade.Buy(dLotOpen,_Symbol,0,0,TP0,scoment))
            {
               vtext="Se ha producido el error "+IntegerToString(GetLastError())+" al abrir una operación de "+DoubleToString(Lots)+".";
               ENUMTXT = PRINT;
               expertLog();
            } 
            break;
      }
      // Contar ops.
      if(countbot()<0) return;
      vtext="Gran tendencia detectada : "+EnumToString(TYPE_POS)+" . "+scoment;
      ENUMTXT = PRINT;
      expertLog();
      return;           
   }
}

//              ------------------------------------------------------------------------------------------------------------------- //
//              ------------------------------------------- HIGHTRENDBOT CODE ------------------------------------------------------ //
//              ------------------------------------------------------------------------------------------------------------------- //


// ------------------------------------------------------------------------------------------------------------------- //
// ------------------------------------------- FRANCISCADA CODE ------------------------------------------------------ //
// ------------------------------------------------------------------------------------------------------------------- //
short goFrancisca()
{
   // Coger las posiciones del symbolo y de los nº mágicos reservados
   ENUM_POSITION_TYPE TYPE_POS;
   double Dprice=0;
   double dOpen=0;
   double dOldTP=0;
   double dOldSL=0;
   double DnewTP=0.0;
   double DnewSL=0.0;
   ulong lTicket=0;
   long lmagic=0;
   int ipos=0;
   
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
         vtext="Error al seleccionar orden función francisca. Error = "+IntegerToString(GetLastError());
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
         if(TYPE_POS==POSITION_TYPE_SELL)
         {
            DnewTP=NormalizeDouble(Dprice-(iFrancisca*2*pips),Digits());
            DnewSL=dOpen-((TakeProfit+(iFrancisca))*pips);
            // Mision cumplida. Nueva misión
            if(dOldSL>0 && dOldSL<DnewSL)
            {
               /////DnewSL=NormalizeDouble(cPos.StopLoss()-((TakeProfit/2)*pips),Digits());
               DnewSL=NormalizeDouble((dOldSL-(iFrancisca*pips)),Digits());
            }
            else
            {
               DnewSL=NormalizeDouble((Dprice+(iFrancisca*pips)),Digits());
            }
            
            // Control mínimo SL por debajo de precio
            if(DnewSL<Dprice) DnewSL=NormalizeDouble((Dprice+(iFrancisca*pips)),Digits());  
         }
         else
         {
            DnewTP=NormalizeDouble((Dprice+(iFrancisca*2*pips)),Digits());
            DnewSL=dOpen+((TakeProfit+(iFrancisca))*pips);
            if(dOldSL>DnewSL)
            {
               /////DnewSL=NormalizeDouble(cPos.StopLoss()+((TakeProfit/2)*pips),Digits());
               DnewSL=NormalizeDouble((dOldSL+(iFrancisca*pips)),Digits());
            }
            else
            {
               DnewSL=NormalizeDouble((Dprice-(iFrancisca*pips)),Digits());
            } 
            // Control mínimo SL por debajo de precio
            if(DnewSL>Dprice) DnewSL=NormalizeDouble((Dprice-(iFrancisca*pips)),Digits());
         }
         // Si hay que actualiar por tp de la posición
         if(MathAbs(Dprice-dOldTP)<(iFrancisca*pips))
         { 
         // Actualizar Posicion
            if(!cTrade.PositionModify(lTicket,DnewSL,DnewTP))
            {
               vtext="Error al actualizar Franciscada en ticket "+IntegerToString(cPos.Ticket())+" error:"+IntegerToString(GetLastError());
               ENUMTXT = PRINT;
               expertLog();
               return -1;
            }
            vtext="Actalización Franciscada en ticket "+IntegerToString(cPos.Ticket())+" Nuevo SL:"+DoubleToString(DnewSL)+", TP:"+DoubleToString(DnewTP)+".";
            ENUMTXT = PRINT;
            expertLog();
            // Comprobar operaciones inferiores
            if(FrancisKill()<0) return -1;
         }
      }  
      
   }
   // Franciscada finalizada
   return 1;
}
// Funtion will be kill previous op of Franciscana triggered correctly
short FrancisKill()
{
   long lmagic;
   ulong lstep;
   lstep=GetStep();
   // Si es nivel 0 return 1
   if(lstep==0) return 1;
   lstep=lstep-1;

   lmagic=cPos.Magic();
   // Recorrer las posiciones abiertas, si la posición es igual al step anterior matar
   // Recorrer todas las posiciones
   for(int i=0;i<PositionsTotal();i++) // returns the number of current positions
   {
      if(!cPos.SelectByIndex(i))
      {
         vtext="Error al seleccionar orden función francisca. Error = "+IntegerToString(GetLastError());
         ENUMTXT = PRINT;
         expertLog();
         continue;
      }
      if (_Symbol==cPos.Symbol() && (cPos.Magic()==lmagic))
      {
         if(lstep==GetStep())
         {
            if(!cTrade.PositionClose(cPos.Ticket()))
            {
               vtext="Error en FrancisKill cerrar el ticket "+IntegerToString(cPos.Ticket())+" error:"+IntegerToString(GetLastError());
               ENUMTXT = PRINT;
               expertLog();
               continue;
            }
            vtext="FrancisKill realizado.Ticket cerrado: "+IntegerToString(cPos.Ticket());
            ENUMTXT = PRINT;
            expertLog();                
         }
      }
    }   
   
   // FrancisKill finalizada
   return 1;
}

//              ------------------------------------------------------------------------------------------------------------------- //
//              ------------------------------------------- FRANCISCADA CODE ------------------------------------------------------ //
//              ------------------------------------------------------------------------------------------------------------------- //

// ------------------------------------------------------------------------------------------------------------------- //
// ------------------------------------------- EQUALITY FUNTIONS ----------------------------------------------------- //
// ------------------------------------------------------------------------------------------------------------------- //

short CheckEquality()
{
   // Recorrer todos los hilos y si esta en beneficios cerrar
   for(int i=0;i<9;i++) // Recorrer los posibles hilos y si esta en uso evaluar
   {
      if(ATRENDBOT[i]>0)
      {
         if(CheckEqualityThread(ATRENDBOT[i])<0) return -1;
      }
   }
   // Bien
   return 1;
}

short CheckEqualityThread(long lMagic)
{
   ulong lstep=0;
   int iPos=0;
   double dEqThread=0;
   double dEqmin=dImpThreadClose*iCent;
   ulong aTicket[];
   bool bhighlot=false;
   iPos=(int)(lMagic-MAGICTREND);
   // Cargar paso max hilo
   if(!cPos.SelectByTicket(ATRENDMAX[iPos]))
   {
      vtext="Error en CheckEqualityThread al seleccionar ticket "+IntegerToString(ATRENDMAX[iPos])+" : "+IntegerToString(GetLastError());
      ENUMTXT = PRINT;
      expertLog();
      return -1;
   }
   // Por cada step obtener una rentabilidad mínima
   iPos=(int)GetStep();
   dEqmin+=iPos*iCent;
   if(iPos>6)
   {
      bhighlot=true;
      //dEqThread=0;
      vtext="Grandes lotajes.Cerrar hilo si esta en positivo.";
      ENUMTXT = PRINT;
      expertLog(); 
   }
 
   // Recorrer todas las op del hilo
   iPos=0;
   for(int i=0;i<PositionsTotal();i++) // returns the number of current positions
   {
      if(!cPos.SelectByIndex(i))
      {
         Print("Error al seleccionar orden. Error = ",GetLastError());
         return -1;
      }
      if(_Symbol!=cPos.Symbol()) continue; 
      // Check Bot
      if(cPos.Magic()==lMagic)
      {
         iPos+=1;
         ArrayResize(aTicket,iPos);
         ArrayFill(aTicket,iPos-1,1,0);
         aTicket[iPos-1]=cPos.Ticket();
         // Tener presente comisión Swap y profit
         // Añadir la comisión actual
         dEqThread+=getComisionPos();
         dEqThread+=cPos.Swap();
         dEqThread+=cPos.Profit();
      }
   } 
   //printf("ACCOUNT_COMMISSION_BLOCKED = %G",AccountInfoDouble(ACCOUNT_COMMISSION_BLOCKED));
   // Controlar si hay ganancias entre todas
   if(dEqThread>dEqmin && iPos>1) 
   {
      if(SavePointThread(aTicket,bhighlot)<0) return -1;
   } 
   // Bien
   return 1;
}

short SavePointThread(ulong &aTicket[],bool bHighLot=false)
{
   int iPosTotal=ArraySize(aTicket);
   // Recorrer todas las posiciones del array
   for(int i=0;i<iPosTotal;i++) // returns the number of current positions
   {  
      if(!cPos.SelectByTicket(aTicket[i]))
      {
         vtext="Error al seleccionar orden en función SavePointThread. Error = "+IntegerToString(GetLastError());
         ENUMTXT = PRINT;
         expertLog();
         return -1;
      }   
      // Posición en ganancias tocar SL
      if(cPos.Profit()>0 && bHighLot==false)
      {
         if(AccSlEquelity()<0) return -1;
         vtext="Ticket "+IntegerToString(cPos.Ticket())+" SL actalizado en función SavePointThread.";
         ENUMTXT = PRINT;
         expertLog();
      }
      // Cerrar operación erronea
      else
      {
         if(!cTrade.PositionClose(cPos.Ticket()))
         {
            vtext="Error al actualizar SavePointThread en ticket "+IntegerToString(cPos.Ticket())+" error:"+IntegerToString(GetLastError());
            ENUMTXT = PRINT;
            expertLog();
            return -1;
         }
         vtext="SavePointThread close en ticket "+IntegerToString(cPos.Ticket());
         ENUMTXT = PRINT;
         expertLog();            
      }
   }
   // Bien
   return 1;  
}
// Contar dirección ultimas barras
int CheckBarCont()
{
   int icont=0;
   for(int i=0;i<ArraySize(rLastBars);i++)
   {
   	if(rLastBars[i].open>rLastBars[i].close)
   	{
   	   icont-=1;
   	}
   	else
   	{
   	   icont+=1;
   	}
   }
   // Return dir
   return icont;
}   

// Sólo actualizar si el SL es 0 o es menor a ganancias
short AccSlEquelity()
{
   ENUM_POSITION_TYPE TYPE_POS=POSITION_TYPE_BUY;
   ulong lTiket=0;
   double dPrice=0;
   double dNewTP=0;
   double dNewSL=0;
   double dOldSL=0;
   double dOpen=0;
   
   TYPE_POS=cPos.PositionType();
   lTiket=cPos.Ticket();
   dOpen=cPos.PriceOpen();
   dOldSL=cPos.StopLoss();
   dPrice=cPos.PriceCurrent();
   // Control del tipo de SL
   // Controlar si ya tiene SL en ganancias dejar
   if(TYPE_POS==POSITION_TYPE_SELL)
   {
      dNewSL=NormalizeDouble(dPrice+(iFrancisca*pips),Digits());
      if(dOpen-((TakeProfit-iFrancisca)*pips)>dOldSL && dOldSL>0)
      {
         dNewSL=NormalizeDouble(dOldSL-(iFrancisca*pips),Digits());
      }
      dNewTP=NormalizeDouble(dPrice-(iFrancisca*3*pips),Digits());
      // Check values in range
      if(dNewSL<=dPrice || dNewTP>=dPrice)
      {
         dNewSL=dPrice+(iFrancisca*pips);
         dNewTP=dPrice-(iFrancisca*3*pips);
      }
   }
   else
   {
      dNewSL=NormalizeDouble(dPrice-(iFrancisca*pips),Digits());
      if(dOpen+((TakeProfit-iFrancisca)*pips)<dOldSL)
      {
         dNewSL=NormalizeDouble(dOldSL+(iFrancisca*pips),Digits());
      }
      dNewTP=NormalizeDouble(dPrice+(iFrancisca*3*pips),Digits());
      // Check values in range
      if(dNewSL>=dPrice || dNewTP<=dPrice)
      {
         dNewSL=dPrice-(iFrancisca*pips);
         dNewTP=dPrice+(iFrancisca*3*pips);
      }
   }
   // Actualizar Posicion
   if(!cTrade.PositionModify(lTiket,dNewSL,dNewTP))
   {
      vtext="Error al actualizar AccSlEquelity en ticket "+IntegerToString(cPos.Ticket())+" error:"+IntegerToString(GetLastError());
      ENUMTXT = PRINT;
      expertLog();
      return -1;
   }
   // Bien 
   return 1;
}

// Max step Witch SL allway OK
short SetSLMax()
{
   double dOpen = 0.00;
   double dSL = 0.00;
   double dProfit = 0.00;
   double dCheck = 0.00;
   double dPriceNow = 0.00;
   ulong ltiket = 0;
   int idir=0;
   ENUM_POSITION_TYPE TYPE_POS=POSITION_TYPE_BUY;
   // Coger dir
   idir=CheckBarCont();
   // Recorrer el Array de MAX

   for(int i=0;i<ArraySize(ATRENDMAX);i++)
   {
      if(ATRENDMAX[i]==0) continue;
      if(!cPos.SelectByTicket(ATRENDMAX[i]))
      {
         vtext="Error en SetSLMax seleccionado ticket "+IntegerToString(ATRENDMAX[i])+". Últmo error encontrado:"+IntegerToString(GetLastError())+".No se evaluará.";
         ENUMTXT = PRINT;
         expertLog();
         continue;
      }
      if(_Symbol!=cPos.Symbol()) continue;
      // Sólo si tiene SL
      dOpen=cPos.PriceOpen();
      dSL=cPos.StopLoss();
      ////////////if(dSL==0) continue;
      TYPE_POS=cPos.PositionType();
      ltiket=cPos.Ticket();
      dPriceNow=cPos.PriceCurrent();
      // Control de congelación cerca del precio de SL
      if(MathAbs(dSL-dPriceNow)<iFrancisca*pips)
      {
         FreezeTime=TimeCurrent()+900;
      }
      // Si la dir de las barras es buy y el precio aun esta debajo del open realizar un SetSLMax
      if(TYPE_POS==POSITION_TYPE_SELL && idir<0)
      {
         if(dOpen>dSL && dSL>0) continue;
         // Reset DSL
         dSL=0;        
         dCheck=NormalizeDouble(dOpen-(TakeProfit*2*pips),Digits());
         ///if(dPriceNow<dCheck && cPos.Volume()<dMaxLotSL) 
         if(dPriceNow<dCheck)
         {
            dSL=NormalizeDouble(dOpen-((iFrancisca)*pips),Digits());

         }
      }
      // Si la dir de las barras es sell y el precio aun esta por encima del open realizar un SetSLMax
      if(TYPE_POS==POSITION_TYPE_BUY && idir>0)
      {
         if(dOpen<dSL) continue;
         // Reset DSL
         dSL=0;
         dCheck=NormalizeDouble(dOpen+(TakeProfit*2*pips),Digits());
         //if(dPriceNow>dCheck && cPos.Volume()<dMaxLotSL)
         if(dPriceNow>dCheck)
         {
            dSL=NormalizeDouble(dOpen+((iFrancisca)*pips),Digits());

         } 
      }
      if(dSL!=cPos.StopLoss())
      {
         // El último step no puede tener SL
         if(!cTrade.PositionModify(ltiket,dSL,cPos.TakeProfit()))
         {
            vtext="Error en función SetSLMax al resetear StopLost a 0 del ticket "+IntegerToString(cPos.Ticket())+"(Ant "+DoubleToString(cPos.StopLoss())+") error:"+IntegerToString(GetLastError());
            ENUMTXT = PRINT;
            expertLog();
            continue;
         }
         vtext="SetSLMax ticket "+IntegerToString(cPos.Ticket())+" ha actualizado SL a "+DoubleToString(dSL)+".";
         ENUMTXT = PRINT;
         expertLog();
      }      
   }
   // Bien
   return 1;   
}


//              ------------------------------------------------------------------------------------------------------------------- //
//              ---------------------------------------------- EQUALITY CODE ------------------------------------------------------ //
//              ------------------------------------------------------------------------------------------------------------------- //


///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

///////////////////////////// DEPRECIDED FUNTIONS


// Sólo habre sí los edges de las barras van el la dirección que nos interesa
int CheckEdges(ENUM_POSITION_TYPE TYPE_POS)
{
   double dEdge=0;
   for(int i=0;i<ArraySize(rLastBars);i++)
   {
      switch(TYPE_POS)
      {
         case POSITION_TYPE_SELL:
            // Check high values allways go down
            if(i==0) 
            {
               dEdge=rLastBars[i].high;
               // Añadir 1/2 de TakeProfit
               dEdge-=(TakeProfit*0.5*pips);
            }
            else
            {
               if(rLastBars[i].high>dEdge)
               {
                  vtext="Desactivada creación. La dirección de las barras no es clara.";
                  ENUMTXT = PRINT;
                  expertLog();
                  return 0;
               }
            }
            dEdge=rLastBars[i].high;  
            break;  
      case POSITION_TYPE_BUY:
            // Check low values allways up
            if(i==0) 
            {
               dEdge=rLastBars[i].low;
               // Añadir 1/2 de TakeProfit
               dEdge+=(TakeProfit*0.5*pips);
            }
            else
            {
               if(rLastBars[i].low<dEdge)
               {
                  vtext="Desactivada creación. La dirección de las barras no es clara.";
                  ENUMTXT = PRINT;
                  expertLog();
                  return 0;
               }
            }
            dEdge=rLastBars[i].low;  
            break;
      }
   }   
   // Bien
   return 1;
}
