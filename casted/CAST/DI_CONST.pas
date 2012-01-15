  IK_ESCAPE          :=$01;
  IK_1               :=$02;
  IK_2               :=$03;
  IK_3               :=$04;
  IK_4               :=$05;
  IK_5               :=$06;
  IK_6               :=$07;
  IK_7               :=$08;
  IK_8               :=$09;
  IK_9               :=$0A;
  IK_0               :=$0B;
  IK_MINUS           :=$0C;    (* - on main keyboard *)
  IK_EQUALS          :=$0D;
  IK_BACK            :=$0E;    (* backspace *)
  IK_TAB             :=$0F;
  IK_Q               :=$10;
  IK_W               :=$11;
  IK_E               :=$12;
  IK_R               :=$13;
  IK_T               :=$14;
  IK_Y               :=$15;
  IK_U               :=$16;
  IK_I               :=$17;
  IK_O               :=$18;
  IK_P               :=$19;
  IK_LBRACKET        :=$1A;
  IK_RBRACKET        :=$1B;
  IK_RETURN          :=$1C;    (* Enter on main keyboard *)
  IK_LCONTROL        :=$1D;
  IK_A               :=$1E;
  IK_S               :=$1F;
  IK_D               :=$20;
  IK_F               :=$21;
  IK_G               :=$22;
  IK_H               :=$23;
  IK_J               :=$24;
  IK_K               :=$25;
  IK_L               :=$26;
  IK_SEMICOLON       :=$27;
  IK_APOSTROPHE      :=$28;
  IK_GRAVE           :=$29;    (* accent grave *)
  IK_LSHIFT          :=$2A;
  IK_BACKSLASH       :=$2B;
  IK_Z               :=$2C;
  IK_X               :=$2D;
  IK_C               :=$2E;
  IK_V               :=$2F;
  IK_B               :=$30;
  IK_N               :=$31;
  IK_M               :=$32;
  IK_COMMA           :=$33;
  IK_PERIOD          :=$34;    (* . on main keyboard *)
  IK_SLASH           :=$35;    (* / on main keyboard *)
  IK_RSHIFT          :=$36;
  IK_MULTIPLY        :=$37;    (* * on numeric keypad *)
  IK_LMENU           :=$38;    (* left Alt *)
  IK_SPACE           :=$39;
  IK_CAPITAL         :=$3A;
  IK_F1              :=$3B;
  IK_F2              :=$3C;
  IK_F3              :=$3D;
  IK_F4              :=$3E;
  IK_F5              :=$3F;
  IK_F6              :=$40;
  IK_F7              :=$41;
  IK_F8              :=$42;
  IK_F9              :=$43;
  IK_F10             :=$44;
  IK_NUMLOCK         :=$45;
  IK_SCROLL          :=$46;    (* Scroll Lock *)
  IK_NUMPAD7         :=$47;
  IK_NUMPAD8         :=$48;
  IK_NUMPAD9         :=$49;
  IK_SUBTRACT        :=$4A;    (* - on numeric keypad *)
  IK_NUMPAD4         :=$4B;
  IK_NUMPAD5         :=$4C;
  IK_NUMPAD6         :=$4D;
  IK_ADD             :=$4E;    (* + on numeric keypad *)
  IK_NUMPAD1         :=$4F;
  IK_NUMPAD2         :=$50;
  IK_NUMPAD3         :=$51;
  IK_NUMPAD0         :=$52;
  IK_DECIMAL         :=$53;    (* . on numeric keypad *)
  // $54 to $55 unassigned
  IK_OEM_102         :=$56;    (* < > | on UK/Germany keyboards *)
  IK_F11             :=$57;
  IK_F12             :=$58;
  // $59 to $63 unassigned
  IK_F13             :=$64;    (*                     (NEC PC98) *)
  IK_F14             :=$65;    (*                     (NEC PC98) *)
  IK_F15             :=$66;    (*                     (NEC PC98) *)
  // $67 to $6F unassigned
  IK_KANA            :=$70;    (* (Japanese keyboard)            *)
  IK_ABNT_C1         :=$73;    (* / ? on Portugese (Brazilian) keyboards *)
  // $74 to $78 unassigned
  IK_CONVERT         :=$79;    (* (Japanese keyboard)            *)
  // $7A unassigned
  IK_NOCONVERT       :=$7B;    (* (Japanese keyboard)            *)
  // $7C unassigned
  IK_YEN             :=$7D;    (* (Japanese keyboard)            *)
  IK_ABNT_C2         :=$7E;    (* Numpad . on Portugese (Brazilian) keyboards *)  
  // $7F to 8C unassigned
  IK_NUMPADEQUALS    :=$8D;    (* :=on numeric keypad (NEC PC98) *)
  // $8E to $8F unassigned
  IK_CIRCUMFLEX      :=$90;    (* (Japanese keyboard)            *)
  IK_AT              :=$91;    (*                     (NEC PC98) *)
  IK_COLON           :=$92;    (*                     (NEC PC98) *)
  IK_UNDERLINE       :=$93;    (*                     (NEC PC98) *)
  IK_KANJI           :=$94;    (* (Japanese keyboard)            *)
  IK_STOP            :=$95;    (*                     (NEC PC98) *)
  IK_AX              :=$96;    (*                     (Japan AX) *)
  IK_UNLABELED       :=$97;    (*                        (J3100) *)
  // $98 unassigned
  IK_NEXTTRACK       :=$99;    (* Next Track *)
  // $9A to $9D unassigned    
  IK_NUMPADENTER     :=$9C;    (* Enter on numeric keypad *)
  IK_RCONTROL        :=$9D;
  // $9E to $9F unassigned
  IK_MUTE            :=$A0;    (* Mute *)
  IK_CALCULATOR      :=$A1;    (* Calculator *)
  IK_PLAYPAUSE       :=$A2;    (* Play / Pause *)
  IK_MEDIASTOP       :=$A4;    (* Media Stop *)
  // $A5 to $AD unassigned  
  IK_VOLUMEDOWN      :=$AE;    (* Volume - *)
  // $AF unassigned  
  IK_VOLUMEUP        :=$B0;    (* Volume + *)
  // $B1 unassigned  
  IK_WEBHOME         :=$B2;    (* Web home *)
  IK_NUMPADCOMMA     :=$B3;    (* , on numeric keypad (NEC PC98) *)
  // $B4 unassigned
  IK_DIVIDE          :=$B5;    (* / on numeric keypad *)
  // $B6 unassigned
  IK_SYSRQ           :=$B7;
  IK_RMENU           :=$B8;    (* right Alt *)
  // $B9 to $C4 unassigned
  IK_PAUSE           :=$C5;    (* Pause (watch out - not realiable on some kbds) *)
  // $C6 unassigned
  IK_HOME            :=$C7;    (* Home on arrow keypad *)
  IK_UP              :=$C8;    (* UpArrow on arrow keypad *)
  IK_PRIOR           :=$C9;    (* PgUp on arrow keypad *)
  // $CA unassigned
  IK_LEFT            :=$CB;    (* LeftArrow on arrow keypad *)
  // $CC unassigned  
  IK_RIGHT           :=$CD;    (* RightArrow on arrow keypad *)
  // $CE unassigned
  IK_END             :=$CF;    (* End on arrow keypad *)
  IK_DOWN            :=$D0;    (* DownArrow on arrow keypad *)
  IK_NEXT            :=$D1;    (* PgDn on arrow keypad *)
  IK_INSERT          :=$D2;    (* Insert on arrow keypad *)
  IK_DELETE          :=$D3;    (* Delete on arrow keypad *)
  IK_LWIN            :=$DB;    (* Left Windows key *)
  IK_RWIN            :=$DC;    (* Right Windows key *)
  IK_APPS            :=$DD;    (* AppMenu key *)
  IK_POWER           :=$DE;
  IK_SLEEP           :=$DF;
  // $E0 to $E2 unassigned
  IK_WAKE            :=$E3;    (* System Wake *)
  // $E4 unassigned
  IK_WEBSEARCH       :=$E5;    (* Web Search *)
  IK_WEBFAVORITES    :=$E6;    (* Web Favorites *)
  IK_WEBREFRESH      :=$E7;    (* Web Refresh *)
  IK_WEBSTOP         :=$E8;    (* Web Stop *)
  IK_WEBFORWARD      :=$E9;    (* Web Forward *)
  IK_WEBBACK         :=$EA;    (* Web Back *)
  IK_MYCOMPUTER      :=$EB;    (* My Computer *)
  IK_MAIL            :=$EC;    (* Mail *)
  IK_MEDIASELECT     :=$ED;    (* Media Select *)


(*
 *  Alternate names for keys, to facilitate transition from DOS.
 *)
  IK_BACKSPACE      :=IK_BACK;      (* backspace *)
  IK_NUMPADSTAR     :=IK_MULTIPLY;  (* * on numeric keypad *)
  IK_LALT           :=IK_LMENU;     (* left Alt *)
  IK_CAPSLOCK       :=IK_CAPITAL;   (* CapsLock *)
  IK_NUMPADMINUS    :=IK_SUBTRACT;  (* - on numeric keypad *)
  IK_NUMPADPLUS     :=IK_ADD;       (* + on numeric keypad *)
  IK_NUMPADPERIOD   :=IK_DECIMAL;   (* . on numeric keypad *)
  IK_NUMPADSLASH    :=IK_DIVIDE;    (* / on numeric keypad *)
  IK_RALT           :=IK_RMENU;     (* right Alt *)
  IK_UPARROW        :=IK_UP;        (* UpArrow on arrow keypad *)
  IK_PGUP           :=IK_PRIOR;     (* PgUp on arrow keypad *)
  IK_LEFTARROW      :=IK_LEFT;      (* LeftArrow on arrow keypad *)
  IK_RIGHTARROW     :=IK_RIGHT;     (* RightArrow on arrow keypad *)
  IK_DOWNARROW      :=IK_DOWN;      (* DownArrow on arrow keypad *)
  IK_PGDN           :=IK_NEXT;      (* PgDn on arrow keypad *)

(*
 *  Alternate names for keys originally not used on US keyboards.
 *)

  IK_PREVTRACK      :=IK_CIRCUMFLEX;  (* Japanese keyboard *)

  IK_MOUSELEFT       :=$F0;
  IK_MOUSERIGHT      :=$F1;
  IK_MOUSEMIDDLE     :=$F2;
