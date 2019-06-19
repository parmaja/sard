module sard.scanners;
/**
*   This file is part of the "SARD"
*
*   @license   The MIT License (MIT) Included in this distribution
*   @author    Zaher Dirkey <zaherdirkey at yahoo dot com>
*/

/**
*   @module: 
*       Tokenizers: Scan the source code and generate runtime objects
*
*   Lexer: divied the source code (line) and pass it to small scanners, tokenizer tell it when it finished
*   Tokenizer: Take this part of source code and convert it to control, operator or token/indentifier
*/

import std.stdio;
import std.conv;
import std.array;
import std.string;
import std.stdio;
import std.uni;
import std.datetime;

import sard.utils;
import sard.classes;
import sard.lexers;
import sard.types;
import sard.parsers;
import sard.objects;
import sard.runtimes;
import sard.operators;

import minilib.sets;

static immutable char[] sEOL = ['\0', '\n', '\r'];
static immutable char[] sWhitespace = sEOL ~ [' ', '\t'];
static immutable char[] sNumberOpenChars = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
static immutable char[] sNumberChars = sNumberOpenChars ~ ['.', 'x', 'h', 'a', 'b', 'c', 'd', 'e', 'f'];
static immutable char[] sSymbolChars = ['"', '\'', '\\'];
static immutable char[] sIdentifierSeparator = ".";
static immutable char[] sEscape = ['\\'];

//const sColorOpenChars = ['#',];
//const sColorChars = sColorOpenChars ~ ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'a', 'b', 'c', 'd', 'e', 'f'];

/**
    Tokenizers
*/

class Whitespace_Tokenizer: Tokenizer
{
protected:
    override void scan(const string text, int started, ref int column, ref bool resume)
    {
        column++;
        while (indexInStr(column, text) && (lexer.isWhiteSpace(text[column])))
            column++;

        lexer.parser.setWhiteSpaces(text[started..column]);
        resume = false;
    }

    override bool accept(const string text, int column){
        return lexer.isWhiteSpace(text[column]);
    }
}

class Identifier_Tokenizer: Tokenizer
{
protected:
    override void scan(const string text, int started, ref int column, ref bool resume)
    {
        column++;
        while (indexInStr(column, text) && (lexer.isIdentifier(text[column], false)))
            column++;

        lexer.parser.setToken(Token(Ctl.Token, Type.Identifier, text[started..column]));
        resume = false;
    }

    override bool accept(const string text, int column){
        return lexer.isIdentifier(text[column], true);   
    }
}

class Number_Tokenizer: Tokenizer
{
protected:
    override void scan(const string text, int started, ref int column, ref bool resume)
    {
        column++;
        while (indexInStr(column, text) && (lexer.isNumber(text[column], false)))
            column++;    

        lexer.parser.setToken(Token(Ctl.Token, Type.Number, text[started..column]));
        resume = false;
    }

    override bool accept(const string text, int column){
        return lexer.isNumber(text[column], true);   
    }
}

class Control_Tokenizer: Tokenizer
{
protected:
    override void scan(const string text, int started, ref int column, ref bool resume)
    {
        Control control = lexer.controls.scan(text, column);
        if (control !is null)
            column = column + control.name.length;
        else
            error("Unkown control started with " ~ text[started]);

        lexer.parser.setControl(control);
        resume = false;
    }

    override bool accept(const string text, int column)
    {
        return lexer.isControl(text[column]);
    }
}

class Operator_Tokenizer: Tokenizer
{
protected:
    override void scan(const string text, int started, ref int column, ref bool resume)
    {
        Operator operator = lexer.operators.scan(text, column);
        if (operator !is null)
            column = column + operator.name.length;
        else
            error("Unkown operator started with " ~ text[started]);

        lexer.parser.setOperator(operator);
        resume = false;
    }

    override bool accept(const string text, int column){
        return lexer.isOperator(text[column]);   
    }
}

// Single line comment 

class LineComment_Tokenizer: Tokenizer
{
protected:
    override void scan(const string text, int started, ref int column, ref bool resume)
    {                                   
        column++;
        while (indexInStr(column, text) && (!lexer.isEOL(text[column])))
            column++;
        column++;//Eat the EOF char
        resume = false;
    }

    override bool accept(const string text, int column){
        return scanText("//", text, column);
    }
}

class BlockComment_Tokenizer: Tokenizer
{
protected:
    override void scan(const string text, int started, ref int column, ref bool resume)
    {
        while (indexInStr(column, text))
        {
            if (scanText("*/", text, column)) 
            {
                resume = false;
                return;
            }
            column++;
        }
        column++;//Eat the second chat //not sure
        resume = true;
    }

    override bool accept(const string text, int column){
        return scanText("/*", text, column);
    }
}

//Comment object {* *}
class Comment_Tokenizer: BufferedMultiLine_Tokenizer
{
    this()
    {
        super();
        openSymbol = "{*";
        closeSymbol = "*}";      
    }

    override void setToken(string text)
    {
        lexer.parser.setToken(Token(Ctl.Token, Type.Comment, text));
    }
}

/* Single Quote String */

class SQString_Tokenizer: String_Tokenizer
{
protected:
    this(){
        super();
        openSymbol = "\'";
        closeSymbol = "\'";      
    }
}

/* Double Quote String */

class DQString_Tokenizer: String_Tokenizer
{
protected:
    this()
    {
        super();
        openSymbol = "\"";
        closeSymbol = "\"";      
    }
}

class Escape_Tokenizer: Tokenizer
{
protected:    
    override void scan(const string text, int started, ref int column, ref bool resume)
    {
        int pos = column;
        column++; //not need first char, it is not pass from isIdentifier
        //print("Hello "\n"World"); //but add " to the world
        while (indexInStr(column, text) && (lexer.isIdentifier(text[column], false)))
            column++;    

        lexer.parser.setToken(Token(Ctl.Token, Type.Escape, text[pos..column]));
        resume = false;
    }

    override bool accept(const string text, int column){
        return sEscape.indexOf(text[column]) >= 0;
    }
}

/*-----------------------*/
/*     Script Lexer      */
/*-----------------------*/

class CodeLexer: Lexer
{
public:
    this(){
        super();
        with(controls)
        {
            add("", Ctl.None);////TODO i feel it is so bad
            add("", Ctl.Token);
            add("", Ctl.Operator);
            add("", Ctl.Start);
            add("", Ctl.Stop);
//            add("", Ctl.Declare);
//            add("", Ctl.Assign);
//            add("", Ctl.Let);

            add("(", Ctl.OpenParams);
            add("[", Ctl.OpenArray);
            add("{", Ctl.OpenBlock);
            add(")", Ctl.CloseParams);
            add("]", Ctl.CloseArray);
            add("}", Ctl.CloseBlock);
            add(";", Ctl.End);
            add(",", Ctl.Next);
            add(":", Ctl.Declare);
            add(":=", Ctl.Assign);
        }

        with (operators)
        {
            add(new OpPlus);
            add(new OpSub);
            add(new OpMultiply);
            add(new OpDivide);

            add(new OpEqual);
            add(new OpNotEqual);
            add(new OpAnd);
            add(new OpOr);
            add(new OpNot);

            add(new OpGreater);
            add(new OpLesser);

            add(new OpPower);
        }

        with (this)
        {
            add(new Whitespace_Tokenizer());
            add(new BlockComment_Tokenizer());
            add(new Comment_Tokenizer());
            add(new LineComment_Tokenizer());
            add(new Number_Tokenizer());
            add(new SQString_Tokenizer());
            add(new DQString_Tokenizer());
            add(new Escape_Tokenizer());
            add(new Control_Tokenizer());
            add(new Operator_Tokenizer()); //Register it after comment because comment take /*
            add(new Identifier_Tokenizer());//Sould be last one                           
        }
    }

    override bool isEOL(char vChar)
    {
        return sEOL.indexOf(vChar) >= 0;
    }

    override bool isWhiteSpace(char vChar, bool vOpen = true)
    {
        return sWhitespace.indexOf(vChar) >= 0;
    }

    override bool isControl(char vChar)
    {
        return controls.isOpenBy(vChar);
    }

    override bool isOperator(char vChar)
    {
        return operators.isOpenBy(vChar);
    }

    override bool isNumber(char vChar, bool vOpen = true)
    {
        bool r;
        if (vOpen)
            r = sNumberOpenChars.indexOf(vChar) >= 0;
        else
            r = sNumberChars.indexOf(vChar) >= 0;
        return r;
    }

    override bool isSymbol(char vChar)
    {
        return sSymbolChars.indexOf(vChar) >= 0;
    }

    override bool isIdentifier(char vChar, bool vOpen = true)
    {
        return super.isIdentifier(vChar, vOpen); //we do not need to override it, but it is nice to see it here
    }
}

/**
*
*   Plain Lexer
*
*/

class OpenPreprocessor_Tokenizer: Tokenizer
{
protected:
    override void scan(const string text, int started, ref int column, ref bool resume)
    {
        int pos = column;
        column++;
        while (indexInStr(column, text) && (lexer.isWhiteSpace(text[column])))
            column++;

        lexer.parser.setWhiteSpaces(text[pos..column]);
        resume = false;
    }

    override bool accept(const string text, int column){
        return lexer.isWhiteSpace(text[column]);
    }
}

class PlainLexer: Lexer
{
    this()
    {
        with(controls)
        {
            add("<?", Ctl.OpenPreprocessor);
        }

        with(this)
        {
            add(new Whitespace_Tokenizer());
            add(new OpenPreprocessor_Tokenizer());
        }
    }

    override bool isEOL(char vChar)
    {
        return sEOL.indexOf(vChar) >= 0;
    }

    override bool isWhiteSpace(char vChar, bool vOpen = true)
    {
        return sWhitespace.indexOf(vChar) >= 0;
    }

    override bool isControl(char vChar)
    {
        return controls.isOpenBy(vChar);
    }

    override bool isOperator(char vChar)
    {
        return false;
    }

    override bool isNumber(char vChar, bool vOpen = true)
    {
        return false;
    }

    override bool isSymbol(char vChar)
    {
        return sSymbolChars.indexOf(vChar) >= 0;
    }
}


class HighlighterLexer: CodeLexer
{
    this(){
        super();
        trimSymbols = false;
    }
}
