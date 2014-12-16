module sard.classes;

import std.string;
import std.uni;
import std.array;
import std.range;
import minilib.metaclasses;

/**
  This file is part of the "SARD"

  @license   The MIT License (MIT) Included in this distribution
  @author    Zaher Dirkey <zaher at parmaja dot com>

*/

class SardException : Exception {
  private uint _code;

  @property uint code() { return _code; }
  public:
    this(string msg) {
      super(msg);
    }
}

class SardParserException : Exception {
  private int _line;
  private int _column;

  @property {
    int line() {
      return _line;
    }

    int column() {
      return _column;
    }
  }

  this(string msg, int line, int column ) {
    _line = line;
    _column = column;
    super(msg);
  }
}

class SardObject: Object {

  void prepare() {
  };

  this() {
    prepare(); 
  }
}

class SardObjects(T): SardObject {
  private:
    T[] _items;
  public
    alias _items this;

  protected:
    int add(T object) {
      _items = _items  ~ object;
      return _items.length - 1;
    }

  public:
    T getItem(int index) {
      return _items[index];
    }

    T opIndex(size_t index) {
      return getItem(index);
    }

    @property int count(){
      return _items.length;
    }

    T last(){
      if (_items.length == 0)
        return null;
      else
        return _items[_items.length - 1];
    }
}

class SardNamedObject: SardObject{
  string name;
}

class SardNamedObjects(T): SardObjects!T {//TODO check T is SardNamedObject

  public:
    T find(string aName) {
      int i = 0;
      T result = null;
      while (i < count) {
        if (icmp(aName, this[i].name) == 0) {
          result = this[i];
          break;
        }
      }
      return result;
    }
}

enum SardControl {
  ctlNone,
  ctlStart, //Start parsing
  ctlStop, //Start parsing
  ctlDeclare, //Declare a class of object
  ctlAssign, //Assign to object/variable used as :=
  //ctlLet, //Same as assign in the initial but is equal operator if not in initial statment used to be =
  ctlNext, //End Params, Comma
  ctlEnd, //End Statement Semicolon
  ctlOpenBlock, // {
  ctlCloseBlock, // }
  ctlOpenParams, // (
  ctlCloseParams, // )
  ctlOpenArray, // [
  ctlCloseArray // ]
}

class SardStack(T): SardObject {

  static class SardStackItem: SardObject {
    protected {
      T object; //renamed it to object
      SardStackItem parent;
    }

    public {
      SardStack owner;
      int level;
    }
  }

  private {
    int _count;
    SardStackItem _currentItem;
  }

  public {
    @property {
      int count() {
        return _count;
      }

      SardStackItem currentItem() {
        return _currentItem;
      }
    }
  }

  protected {
    T getParent() {
      if (_currentItem is null)
        return null;
      else if (_currentItem.parent is null)
        return null;
      else
        return _currentItem.parent.object;
    }

    T getCurrent() {
      if (currentItem is null)
        return null;
      else
        return currentItem.object;
    }

    void afterPush() {

    };

    void beforePop() {
    };
  }

  public {

    bool isEmpty() {
      return currentItem is null;
    }

    void push(T vObject) {
      SardStackItem aItem;

      if (vObject is null)
        raiseError("Can't push null");

      aItem = new SardStackItem;
      aItem.object = vObject;
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

    T pull(){
      if (currentItem is null)
        raiseError("Stack is empty");
      beforePop();
      T aObject = currentItem.object;
      SardStackItem aItem = currentItem;
      _currentItem = aItem.parent;
      _count--;
      return aObject;
    }

    T peek(){
      if (currentItem is null)
        raiseError("Stack is empty"); //TODO maybe return nil
      return currentItem.object;
    }

    void pop() {
      if (currentItem is null)
        raiseError("Stack is empty");
      beforePop();
      T aObject = currentItem.object;
      SardStackItem aItem = currentItem;
      _currentItem = aItem.parent;
      _count--;

      //    destroy(aItem);
      //    destroy(aObject);
    }

  public:
    @property {
      T current() {
        return getCurrent();
      }
      T parent() {
        return getParent();
      }
    }
  }
}

class SardScanner: SardObject {
  private:
    SardLexical _lexical;

    public @property SardLexical lexical() { return _lexical; } ;

  protected:
    //Return true if it done, next will auto detect it detect
    abstract bool Scan(const string text, inout int Column);
    bool accept(const string text, inout int column){
      return false;
    }
    //This function call when switched to it

    void switched() {
      //Maybe reseting buffer or something
    }
  public:
    string collected; //buffer
    SardScanner scanner;

    void prepare(SardLexical lexical) { //todo maybe rename to opCall
      _lexical = lexical;
    }

    this(SardLexical lexical){ 
      prepare(lexical); //TODO check it for MetaClass
      super();
    }

    ~this(){
    }
}

class SardLexical: SardObjects!SardScanner{
  private:
    int _line;
    SardScanner _scanner;

  public:
    @property {
      int line() { return _line; };
      SardScanner scanner() { return _scanner; } ;
    }

    SardParser _parser;

  protected:
    @property {
      SardParser parser() { return _parser; };
      SardParser parser(SardParser value) { return _parser = value; }
    }

  public:
    abstract bool isWhiteSpace(char vChar, bool vOpen= true);
    abstract bool isControl(char vChar);
    abstract bool isOperator(char vChar);
    abstract bool isNumber(char vChar, bool vOpen = true);

    abstract bool isIdentifier(char vChar, bool vOpen = true){
      bool r = !isWhiteSpace(vChar) && !isControl(vChar) && !isOperator(vChar);
      if (vOpen)
        r = r && !isNumber(vChar, vOpen);
      return r;
    }

  public:
    SardScanner detectScanner(const string text, inout int column) {
      SardScanner r = null;

      int i = 0;
      while (i < count) {
        if ((this[i] != r) && this[i].accept(text, column)) {
          r = this[i];
          break;
        }
        i++;
      }

      if (r is null)
        raiseError("Scanner not found:" ~ text[column]);
      switchScanner(r);
      return r;
    }

    void switchScanner(SardScanner nextScanner) {
      if (_scanner != nextScanner) {

        _scanner = nextScanner;
        if (_scanner is null)
          _scanner.switched();
      }

    }

    SardScanner findClass(const ClassInfo scannerClass) {
      int i = 0;
      while (i < count) {
        if (this[i].classinfo == scannerClass) {
          return this[i];
        }
        i++;
      }
      return null;
    }

    //This find the class and switch to it
    void SelectScanner(ClassInfo scannerClass) {
      SardScanner aScanner = findClass(scannerClass);
      if (aScanner is null)
        raiseError("Scanner not found");
      switchScanner(aScanner);
    }

    SardScanner addScanner(ClassInfo scannerClass) {
      SardScanner scanner;
      //scanner = new typeof(scannerClass);
      scanner = cast(SardScanner)scannerClass.create(); pragma(msg, "Need to review");
      scanner.prepare(this);

      add(scanner);
      return scanner;
    }

    void scanLine(const string text, const int aLine) {
        int _line = aLine;
        int column = 1; //start of pascal string is 1
        int l = text.length;
        if (scanner is null)
          detectScanner(text, column);
        while (column <= l)
        {
          int oldColumn = column;
          SardScanner oldScanner = _scanner;
          try {
            if (scanner.Scan(text, column))
              detectScanner(text, column);

            if ((oldColumn == column) && (oldScanner == _scanner))
              raiseError("Feeder in loop with: " ~ _scanner.classinfo.name); //todo becarfull here
          }
          catch {
            /*on E: EsardException do
            {
              raise EsardParserException.Create(E.Message, Column, Line);
            }*/
          }
        }
    }
};

class SardFeeder: SardObject {
  private:
    bool _active;
    string _ver;
    string _charset;
    SardLexical _lexical; //TODO: use stack to wrap the code inside <?sard ... ?>,
                          //the current one must detect ?> to stop scanning and pop
                          //but the other lexcial will throw none code to output provider

  public:
    @property {
      bool active() { return _active; }
      string ver() { return _ver; }
      string charset() { return _charset; }

      SardLexical lexical() { return _lexical; }
      SardLexical lexical(SardLexical value) {
      if (_lexical == value)
        return _lexical;
      if (active)
        raiseError("You can not set scanner when started!");
      return _lexical = value;
      }
    }
  protected:

    void doStart() {
    }

    void doStop() {

    }

  public:
    this(SardLexical lexical) {
      super();
      _lexical = lexical;
    }

    void scanLine(const string text, const int line) {
      if (!active)
        raiseError("Feeder not started");
      lexical.scanLine(text, line);
    }

    //void scan(const string fileName);
    //void scan(const Stream stream);
    //void scan(const Stream stream);

    void start(){
      if (_active)
        raiseError("File already opened");
      _active = true;
      doStart();
      lexical.parser.start();
    }

    void stop(){
      if (!_active)
        raiseError("File already closed");
      lexical.parser.stop();
      doStop();
      _active = false;

    }
};

enum SrdType {tpNone, tpIdentifier, tpNumber, tpColor, tpString, tpComment }

class SardParser {
  protected:
    void start(){
    }

    void stop(){
    }

    abstract void doSetControl(SardControl aControl);
    abstract void doSetToken(string aToken, SrdType aType);
    abstract void doSetOperator(SardObject aOperator);

  public:
    void setControl(SardControl aControl){
      doSetControl(aControl);
    }

    final void setToken(string aToken, SrdType aType){
      doSetToken(aToken, aType);
    }

    final void setOperator(SardObject aOperator){
      doSetOperator(aOperator);
    }
};

class SardCustomEngine : SardObject {

};

void raiseError(string error) {
  throw new SardException(error);
}

bool scanCompare(string s, const string text, int index){
  return scanText(s, text, index);
}

/**
  return true if s is founded in text at index
*/
bool scanText(string s, const string text, ref int index) {
  bool r = (text.length - index) >= s.length;
  if (r) {
    r = toLower(text[index..s.length]) == toLower(s); //case*in*sensitive
    if (r)
      index = index + s.length;
  }
  return r;
}

string stringRepeat(string s, int count){
  return replicate(s, count);
}