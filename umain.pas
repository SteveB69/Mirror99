unit uMain;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, ExtCtrls,
  Grids;

type

  { TForm1 }

  TForm1 = class(TForm)
    Crunchbuf: TEdit;
    redobuf: TEdit;
    Memo1: TMemo;
    Memo2: TMemo;
    scr: TMemo;
    Sprite: TStringGrid;
    StaticText1: TStaticText;
    StaticText2: TStaticText;
    StaticText3: TStaticText;
    StaticText4: TStaticText;
    Timer1: TTimer;
    procedure FormCreate(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure Memo1DblClick(Sender: TObject);
    procedure Memo2DblClick(Sender: TObject);
    procedure Timer1Timer(Sender: TObject);
  private
    hMapVDP : THandle;
  public

  end;

  TCrunch = array[0..159] of byte;
  TRedo   = array[0..151] of byte;

  TVDP = record case byte of
    1 : (b : Array[0..16383] of byte);
    2 : (d : record            // Layout XB with XB256
               screen : array[0..23,0..31] of byte;
               SAT :   array [0..27] of record
                            y : byte;
                            x : byte;
                            ch: byte;
                            co: byte;
                           end;
               dummy1: array[0..127] of byte;
               Pattern:array [30..143,0..7] of byte;
               SMT :   array [0..27] of record
                            v : byte;
                            h : byte;
                            s1: byte;
                            s2: byte;
                           end;
               dummy2: array[0..15]  of byte;
               ctab  : array[-15..16]  of byte;
               Crunch: array[0..159] of byte;
               redo  : array[0..151] of byte;
               dummy3: array[0..39]  of byte;
               stab :  array[0..629] of byte;
               screen2:array[0..1023] of byte;
               Pattern2: array [160..255,0..7] of byte;
               Pattern3: array [0..159,0..7] of byte;
               ctab2 : array[-15..16]  of byte;
             end );
    end;



var
  Form1: TForm1;

implementation

{$R *.lfm}

{ TForm1 }

uses windows;

var vdp : ^TVDP;
    redosave: TRedo;
    crunchsave: TCrunch;

procedure TForm1.FormCreate(Sender: TObject);
begin
  hMapVDP:=OpenFileMapping(FILE_MAP_ALL_ACCESS,false,'Classic99VDPSharedMemory');
  if hMapVDP=0 then begin
    ShowMessage('Failed to connect to Classic99. ['+IntToStr(GetLastError)+']');
    Application.Terminate;
  end;
  //else ShowMessage('Connected to Classic99!');

  vdp := MapViewOfFile(hMapVDP,FILE_MAP_ALL_ACCESS,0,0,16*1024);         // normal 9918A RAM size 16kB
  if vdp=NIL then begin
    ShowMessage('Failed to map shared memory. ['+IntToStr(GetLastError)+']');
    Application.Terminate;
  end;
  // else ShowMessage('Shared Memeory mapped.');

  Timer1.Enabled:=true;
end;

procedure TForm1.FormShow(Sender: TObject);
var i:integer;
begin
  Sprite.Cells[1,0]:='chr';
  Sprite.Cells[2,0]:='clr';
  Sprite.Cells[3,0]:='row';
  Sprite.Cells[4,0]:='col';
  Sprite.Cells[5,0]:='vy';
  Sprite.Cells[6,0]:='vx';
  Sprite.Cells[7,0]:='s1';
  Sprite.Cells[8,0]:='s2';

  for i:=1 to 28 do Sprite.Cells[0,i]:='#'+inttostr(i);
end;


procedure TForm1.Memo1DblClick(Sender: TObject);
var c,i : integer;
    s : string;
begin
  Memo1.Clear;
  for c:=30 to 143 do begin
    s:=IntToStr(c)+' '+char(c)+' - ';
    for i:=0 to 7 do s:=s+IntToHex(vdp^.d.Pattern[c,i]);
    Memo1.Append(s);
  end;
  memo1.SelStart:=0;
end;


procedure TForm1.Memo2DblClick(Sender: TObject);
var c,i : integer;
    s : string;
begin
  Memo2.Clear;
  for c:=0 to 255 do begin
    if (c<30) or (c>143) then s:=IntToStr(c)+' - '
                         else s:=IntToStr(c)+' '+char(c)+' - ';
    if c>=160 then for i:=0 to 7 do s:=s+IntToHex(vdp^.d.Pattern2[c,i])
              else for i:=0 to 7 do s:=s+IntToHex(vdp^.d.Pattern3[c,i]);
    Memo2.Append(s);
  end;
  memo2.SelStart:=0;
end;


procedure TForm1.Timer1Timer(Sender: TObject);
var x,y,c,i : integer;
    s : String[160];
    h : String;

begin
  // Screen mirror
  for y:=0 to 23 do begin
    s := '';
    for x:=0 to 31 do begin
      c := vdp^.d.screen[y,x]-96;
      if c<0   then c:=c+256;
      if c<32  then c:=32;
      if c>154 then c:=46;
      s:=s+char(c);
    end;
    if s<>scr.Lines.Strings[y] then scr.Lines.Strings[y]:=s;
  end;
  for i:=0 to 27 do begin
    // SAT Sprite Attribute Table
    if Sprite.Cells[1,i+1]<>inttostr(vdp^.d.SAT[i].ch) then Sprite.Cells[1,i+1]:=inttostr(vdp^.d.SAT[i].ch);
    if Sprite.Cells[2,i+1]<>inttostr(vdp^.d.SAT[i].co) then Sprite.Cells[2,i+1]:=inttostr(vdp^.d.SAT[i].co);
    if Sprite.Cells[3,i+1]<>inttostr(vdp^.d.SAT[i].y)  then Sprite.Cells[3,i+1]:=inttostr(vdp^.d.SAT[i].y);
    if Sprite.Cells[4,i+1]<>inttostr(vdp^.d.SAT[i].x)  then Sprite.Cells[4,i+1]:=inttostr(vdp^.d.SAT[i].x);
    // SMT Sprite Motion Table
    if Sprite.Cells[5,i+1]<>inttostr(vdp^.d.SMT[i].v)  then Sprite.Cells[5,i+1]:=inttostr(vdp^.d.SMT[i].v);
    if Sprite.Cells[6,i+1]<>inttostr(vdp^.d.SMT[i].h)  then Sprite.Cells[6,i+1]:=inttostr(vdp^.d.SMT[i].h);
    if Sprite.Cells[7,i+1]<>inttostr(vdp^.d.SMT[i].s1) then Sprite.Cells[7,i+1]:=inttostr(vdp^.d.SMT[i].s1);
    if Sprite.Cells[8,i+1]<>inttostr(vdp^.d.SMT[i].s2) then Sprite.Cells[8,i+1]:=inttostr(vdp^.d.SMT[i].s2);
  end;

  // Crunch-Buffer
  if not CompareMem(@vdp^.d.Crunch,@crunchsave,160) then begin
    s:=''; h:='';
    for i:=0 to 159 do begin
      c:=vdp^.d.Crunch[i];
      h := h+IntToHex(byte(c))+' ';
      if (c<32) or (c>154) then c:=46;
      s:=s+chr(c);
    end;
    Crunchbuf.Text:=s+' | '+h;
    crunchsave:=vdp^.d.Crunch
  end;

  // Redo-Buffer
  if not CompareMem(@vdp^.d.redo,@crunchsave,152) then begin
    s:=''; h:='';
    for i:=0 to 151 do begin
      c:=vdp^.d.redo[i];
      h := h+IntToHex(byte(c))+' ';
      if (c<32) or (c>154) then c:=46;
      s:=s+chr(c);
    end;
    redobuf.Text:=s+' | '+h;
    redosave := vdp^.d.redo;
  end;
end;

end.

