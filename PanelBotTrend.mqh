//+------------------------------------------------------------------+
//|                                                   Scalperbot.mq5 |
//|                                    Copyright 2019, Usefilm Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+f
#property copyright "Copyright 2020, Usefilm Corp."
#property link      "https://www.mql5.com"
#property version   "1.10"
#include <Controls\CheckGroup.mqh>
#include <Controls\Dialog.mqh>
#include <Controls\Label.mqh>
#include <Controls\Edit.mqh>
#include <Controls\Picture.mqh>
//+------------------------------------------------------------------+
//| defines                                                          |
//+------------------------------------------------------------------+
//--- indents and gaps
//--- for group controls

#define INDENT_LEFT                         (11)      // indent from left (with allowance for border width)
#define INDENT_TOP                          (11)      // indent from top (with allowance for border width)
#define INDENT_RIGHT                        (11)      // indent from right (with allowance for border width)
#define INDENT_BOTTOM                       (11)      // indent from bottom (with allowance for border width)
#define CONTROLS_GAP_X                      (5)       // gap by X coordinate
#define CONTROLS_GAP_Y                      (5)       // gap by Y coordinate
//--- for Imagen
#define IMG_WIDTH                           (145)       // gap by X coordinate
#define IMG_HEIGHT                          (60)       // gap by Y coordinate

//--- for buttons
#define BUTTON_WIDTH                        (100)     // size by X coordinate
#define BUTTON_HEIGHT                       (20)      // size by Y coordinate
//--- for the indication area
#define EDIT_WIDTH                          (140)     // size by X coordinate
#define EDIT_WIDTHHMID                      (95)      // size by X coordinate
#define EDIT_HEIGHT                         (20)      // size by Y coordinate


//+------------------------------------------------------------------+
//| Class CControlsDialog                                            |
//| Usage: main dialog of the Controls application                   |
//+------------------------------------------------------------------+
class CControlsDialog : public CAppDialog
  {
private:
   CCheckGroup       m_check_group;                   // the CheckGroup object
   CPicture          m_picture;                       // CPicture object
   CLabel            m_label1;                        // the label object
   CLabel            m_label2;                        // the label object
   CLabel            m_label3;                        // the label object
   CLabel            m_label4;                        // the label object
   CLabel            m_label5;                        // the label object
   CEdit             m_editMode;                         // the display field object
   CEdit             m_editBear1;                      // the display field object
   CEdit             m_editBULL1;                      // the display field object
   CEdit             m_editBear2;                      // the display field object
   CEdit             m_editBULL2;                      // the display field object
   CEdit             m_editBear3;                      // the display field object
   CEdit             m_editBULL3;                      // the display field object
 
public:
                     CControlsDialog(void);
                    ~CControlsDialog(void);
   //--- create
   virtual bool      Create(const long chart,const string name,const int subwin,const int x1,const int y1,const int x2,const int y2);
   //--- chart event handler
   virtual bool      OnEvent(const int id,const long &lparam,const double &dparam,const string &sparam);
   bool              UpdatePannel(string smode,double dlotbull, double dlotbear, int ihilos, string shilos, double dcommision, double dswap);
 
protected:
   //--- create dependent controls
   bool              CreateCheckGroup(void);
   bool              CreatePicture(void);
   bool              CreateLabel1(void);
   bool              CreateLabelDetails(void);
   bool              CreateEditMode(void);
   bool              CreateEditBearBULL(void);
   //--- handlers of the dependent controls events
  };
//+------------------------------------------------------------------+
//| Event Handling                                                   |
//+------------------------------------------------------------------+
EVENT_MAP_BEGIN(CControlsDialog)
EVENT_MAP_END(CAppDialog)
//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CControlsDialog::CControlsDialog(void)
  {
  }
//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CControlsDialog::~CControlsDialog(void)
  {
  }
//+------------------------------------------------------------------+
//| Create                                                           |
//+------------------------------------------------------------------+
bool CControlsDialog::Create(const long chart,const string name,const int subwin,const int x1,const int y1,const int x2,const int y2)
  {
   if(!CAppDialog::Create(chart,name,subwin,x1,y1,x2,y2))
      return(false);
//--- create dependent controls
   if(!CreateCheckGroup())
      return(false);
   if(!CreatePicture())
      return(false);
   if(!CreateLabel1())
      return(false);
   if(!CreateEditMode())
      return(false);
   if(!CreateLabelDetails())
      return(false);
   if(!CreateEditBearBULL())
      return(false);
//--- succeed
   return(true);
  }
//+------------------------------------------------------------------+
//| Create the "Picture"                                             |
//+------------------------------------------------------------------+
bool CControlsDialog::CreatePicture(void)
  {
//--- coordinates
   int x1=ClientAreaWidth()-CONTROLS_GAP_X-150; // Tamaño de la ventana menos el tamaño de la imagen, -5 del borde.
   int y1=5;
   int x2=0;
   int y2=0;
//--- create
   if(!m_picture.Create(m_chart_id,m_name+"Picture",m_subwin,x1,y1,x2,y2))
      return(false);
//--- benennen wir die bmp-Dateien für die Anzeige des CPicture Steuerelements
   //m_picture.BmpName("\\Experts\\Usebots\\resources\\Bull_bear_Wall_small.bmp");
   m_picture.BmpName("\\Images\\Bear_Bull_yellow_blue.bmp");
   if(!Add(m_picture))
      return(false);
//--- succeed
   return(true);
  }
//+------------------------------------------------------------------+
//| Create the "LabelMode"                                              |
//+------------------------------------------------------------------+
bool CControlsDialog::CreateLabel1(void)
  {
//--- coordinates
   int x1=CONTROLS_GAP_X;
   int y1=CONTROLS_GAP_Y;
   int x2=x1+100;
   int y2=y1+20;
//--- create
   if(!m_label1.Create(m_chart_id,m_name+"Label1",m_subwin,x1,y1,x2,y2))
      return(false);
   if(!m_label1.Text("Bot Mode:"))
      return(false);
   if(!Add(m_label1))
      return(false);
//--- succeed
   return(true);
  }
//+------------------------------------------------------------------+
//| Create the display field "EditMode"                                 |
//+------------------------------------------------------------------+
bool CControlsDialog::CreateEditMode(void)
  {
//--- coordinates
   int x1=CONTROLS_GAP_X+100;
   int y1=CONTROLS_GAP_Y;
   int x2=x1+EDIT_WIDTH;
   int y2=y1+EDIT_HEIGHT;
//--- create Bear
   if(!m_editMode.Create(m_chart_id,m_name+"m_editMode",m_subwin,x1,y1,x2,y2))
      return(false);
   if(!m_editMode.Text("WORKING_BOT"))
      return(false);
   if(!Add(m_editMode))
      return(false);  
   m_editMode.Alignment(WND_ALIGN_LEFT,0,0,INDENT_RIGHT,0);
   // Desactivar control
   if(!m_editMode.ReadOnly(true))
      return(false);
//--- succeed
   return(true);
  }
//+------------------------------------------------------------------+
//| Create the "CheckGroup"                                             |
//+------------------------------------------------------------------+  
bool CControlsDialog::CreateCheckGroup(void)
  {
//--- coordinates
   int x1=CONTROLS_GAP_X;
   int y1=CONTROLS_GAP_Y+IMG_HEIGHT;
   int x2=ClientAreaWidth()-x1;
   int y2=ClientAreaHeight()-CONTROLS_GAP_Y;
//--- create
   if(!m_check_group.Create(m_chart_id,m_name+"CheckGroup",m_subwin,x1,y1,x2,y2))
      return(false);
   if(!Add(m_check_group))
      return(false);
//--- succeed
   return(true);
  }
//+------------------------------------------------------------------+
//| Create the "LabelDetails"                                              |
//+------------------------------------------------------------------+
bool CControlsDialog::CreateLabelDetails(void)
  {
//--- coordinates
   int x1=CONTROLS_GAP_X*2;
   int y1=CONTROLS_GAP_Y*2+IMG_HEIGHT;
   int x2=x1+100;
   int y2=y1+20;
//--- create
   if(!m_label2.Create(m_chart_id,m_name+"Label2",m_subwin,x1,y1,x2,y2))
      return(false);
   if(!m_label2.Text("Lotaje total BULL/Bear "))
      return(false);
   if(!Add(m_label2))
      return(false);
//   -- Label3
   y1=y2+CONTROLS_GAP_Y;
   y2=y1+20;
//--- create
   if(!m_label3.Create(m_chart_id,m_name+"Label3",m_subwin,x1,y1,x2,y2))
      return(false);
   if(!m_label3.Text("Nº Hilos / Motivo "))
      return(false);
   if(!Add(m_label3))
      return(false);
//   -- Label4
   y1=y2+CONTROLS_GAP_Y;
   y2=y1+20;
//--- create
   if(!m_label4.Create(m_chart_id,m_name+"Label4",m_subwin,x1,y1,x2,y2))
      return(false);
   if(!m_label4.Text("Comisión / swap "))
      return(false);
   if(!Add(m_label4))
      return(false);
//   -- Label5
   y1=y2+CONTROLS_GAP_Y;
   y2=y1+20;
//--- succeed
   return(true);
  }
//+------------------------------------------------------------------+
//| Create the display field "EditBearBULL"                         |
//+------------------------------------------------------------------+
bool CControlsDialog::CreateEditBearBULL(void)
  {
//--- coordinates
   int x1=CONTROLS_GAP_X*2+185;
   int y1=CONTROLS_GAP_Y*2+IMG_HEIGHT;
   int x2=x1+EDIT_WIDTHHMID;
   int y2=y1+EDIT_HEIGHT;
   //--- Create BULL
   if(!m_editBULL1.Create(m_chart_id,m_name+"m_editBULL1",m_subwin,x1,y1,x2,y2))
      return(false);
   if(!m_editBULL1.Text(DoubleToString(0,2)))
      return(false);
   if(!Add(m_editBULL1))
      return(false);  
   m_editBULL1.Alignment(ALIGN_CENTER,0,0,INDENT_RIGHT,0);
   // Desactivar control
   if(!m_editBULL1.ReadOnly(true))
      return(false);
   //--- create Bear
   x1=x2+CONTROLS_GAP_X;
   y1=y1;
   x2=x1+EDIT_WIDTHHMID;
   y2=y1+EDIT_HEIGHT;
   if(!m_editBear1.Create(m_chart_id,m_name+"m_editBear1",m_subwin,x1,y1,x2,y2))
      return(false);
   if(!m_editBear1.Text(DoubleToString(0,2)))
      return(false);
   if(!Add(m_editBear1))
      return(false);  
   m_editBear1.Alignment(ALIGN_CENTER,0,0,INDENT_RIGHT,0);
   // Desactivar control
   if(!m_editBear1.ReadOnly(true))
      return(false);
   //--- Create BULL2
   x1=CONTROLS_GAP_X*2+185;
   y1=y1+24;
   x2=x1+EDIT_WIDTHHMID;
   y2=y1+EDIT_HEIGHT;
   if(!m_editBULL2.Create(m_chart_id,m_name+"m_editBULL2",m_subwin,x1,y1,x2,y2))
      return(false);
   if(!m_editBULL2.Text("0"))
      return(false);
   if(!Add(m_editBULL2))
      return(false);  
   m_editBULL2.Alignment(ALIGN_CENTER,0,0,INDENT_RIGHT,0);
   // Desactivar control
   if(!m_editBULL2.ReadOnly(true))
      return(false);
   //--- create Bear2
   x1=CONTROLS_GAP_X+x2;
   y1=y1;
   x2=x1+EDIT_WIDTHHMID;
   y2=y1+EDIT_HEIGHT;
   if(!m_editBear2.Create(m_chart_id,m_name+"m_editBear2",m_subwin,x1,y1,x2,y2))
      return(false);
   if(!m_editBear2.Text("STARTING"))
      return(false);
   if(!Add(m_editBear2))
      return(false);  
   m_editBear2.Alignment(ALIGN_CENTER,0,0,INDENT_RIGHT,0);
   // Desactivar control
   if(!m_editBear2.ReadOnly(true))
      return(false);
   //--- Create BULL3
   x1=CONTROLS_GAP_X*2+185;
   y1=y1+24;
   x2=x1+EDIT_WIDTHHMID;
   y2=y1+EDIT_HEIGHT;
   if(!m_editBULL3.Create(m_chart_id,m_name+"m_editBULL3",m_subwin,x1,y1,x2,y2))
      return(false);
   if(!m_editBULL3.Text(DoubleToString(0,2)))
      return(false);
   if(!Add(m_editBULL3))
      return(false);  
   m_editBULL3.Alignment(ALIGN_CENTER,0,0,INDENT_RIGHT,0);
   // Desactivar control
   if(!m_editBULL3.ReadOnly(true))
      return(false);
   //--- create Bear3
   x1=CONTROLS_GAP_X+x2;
   y1=y1;
   x2=x1+EDIT_WIDTHHMID;
   y2=y1+EDIT_HEIGHT;
   if(!m_editBear3.Create(m_chart_id,m_name+"m_editBear3",m_subwin,x1,y1,x2,y2))
      return(false);
   if(!m_editBear3.Text(DoubleToString(0,2)))
      return(false);
   if(!Add(m_editBear3))
      return(false);  
   m_editBear3.Alignment(ALIGN_CENTER,0,0,INDENT_RIGHT,0);
   // Desactivar control
   if(!m_editBear3.ReadOnly(true))
      return(false);
//--- succeed
   return(true);
  }   
//+------------------------------------------------------------------+
//| Event handler                                                    |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Set check for element                                            |
//+------------------------------------------------------------------+
bool CControlsDialog::UpdatePannel(string smode,double dlotbull, double dlotbear, int ihilos, string shilos, double dcommision, double dswap)
  {
  // Act. mode
   
   if(!m_editMode.Text(smode))
      return(false);
   // Linea 1
   if(!m_editBULL1.Text(DoubleToString(dlotbull,2)))
      return(false); 
   if(!m_editBear1.Text(DoubleToString(dlotbear,2)))
      return(false);
   // Linea 2
   if(!m_editBULL2.Text(IntegerToString(ihilos)))
      return(false); 
   if(!m_editBear2.Text(shilos))
      return(false); 
   // Linea 3
   if(!m_editBULL3.Text(DoubleToString(dcommision,2)))
      return(false); 
   if(!m_editBear3.Text(DoubleToString(dswap,2)))
      return(false); 
// -- All ok
   return(true);
  }
//+------------------------------------------------------------------+
//| Global Variables                                                 |
//+------------------------------------------------------------------+
CControlsDialog ExtDialog;
