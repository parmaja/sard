module sard.classes;
/**
  This file is part of the "SARD"

  @license   The MIT License (MIT) Included in this distribution
  @author    Zaher Dirkey <zaher at parmaja dot com>

*/

alias long srd_int;
alias double srd_float;

class SardException : Exception
{
  private uint _code;

  @property uint code(){ return _code; }

  this(string msg)
  {
    super(msg);
  }
}

class SardParserException : Exception
{
  private int _line;
  private int _column;

  @property int line(){ return _line; }
  @property int column(){ return _column; }

  this(string msg, int line, int column )
  {
    _line = line;
    _column = column; 
    super(msg);
  }
}

class SardObject: Object {

  void created() {
  };

  this() {
    created();
  }
}

class SardObjectList: SardObject {
  SardObject[] _items;

  SardObject opIndex(size_t index) {
    return _items[index];
  }
}

class SardObjects: SardObjectList {
  
}

class SardNamedObjects: SardObjectList {

}


enum SardControl {
                ctlNone,
                ctlStart, //Start parsing
                ctlStop, //Start parsing
                ctlDeclare, //Declare a class of object
                ctlAssign, //Assign to object/variable used as :=
                //    ctlLet, //Same as assign in the initial but is equal operator if not in initial statment used to be =
                ctlNext, //End Params, Comma
                ctlEnd, //End Statement Semicolon
                ctlOpenBlock, // {
                ctlCloseBlock, // }
                ctlOpenParams, // (
                ctlCloseParams, // )
                ctlOpenArray, // [
                ctlCloseArray // ]
  }

class SardStackItem: SardObject {
  protected
    Object anObject; //rename it to object
    SardStackItem parent;
  public
    SardStack owner;
    int level;
}

class SardStack: SardObject {
  private
    int _count;
    SardStackItem _currentItem;

  public @property int count(){ return _count; }
  public @property SardStackItem currentItem(){ return _currentItem; }

  protected
    Object getParent() {
      if (_currentItem is null)
        return null;
      else if (_currentItem.parent is null)
        return null;
      else
        return _currentItem.parent.anObject;
    }

    Object getCurrent(){
      if (currentItem is null)
        return null;
      else
        return currentItem.anObject;
    }

    void afterPush(){

    };

    void beforePop(){
    };

  public

    bool isEmpty(){
      return currentItem is null;
    }

  void push(Object vObject){
    SardStackItem aItem;

    if (vObject is null)
      raiseError("Can't push null");

    aItem = new SardStackItem;
    aItem.anObject = vObject;
    aItem.parent = _currentItem;
    aItem.owner = this;
    if (_currentItem is null) 
      aItem.level = 0;
    else
      aItem.level = _currentItem.level + 1;
    _currentItem = aItem;
    _count++;
    afterPush();
  }

  void pop() {
  
    if (currentItem is null)
       raiseError("Stack is empty");
    beforePop;
    Object aObject = currentItem.anObject;
    SardStackItem aItem = currentItem;
    currentItem = aItem.Parent;
    _count--;
    
//    aItem.Free;
//    aObject.Free;
  }
}


void raiseError(string error){
  throw new SardException(error);
}

/*function ScanCompare(S: string; const Text: string; Index: Integer): Boolean;
function ScanText(S: string; const Text: string; var Index: Integer): Boolean;
function StringRepeat(S: string; C: Integer): string;*/
