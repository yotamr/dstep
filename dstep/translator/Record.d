/**
 * Copyright: Copyright (c) 2012 Jacob Carlborg. All rights reserved.
 * Authors: Jacob Carlborg
 * Version: Initial created: may 1, 2012
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 */
module dstep.translator.Record;

import mambo.core._;

import clang.c.Index;
import clang.Cursor;
import clang.Visitor;
import clang.Util;

import dstep.translator.Translator;
import dstep.translator.Declaration;
import dstep.translator.Output;
import dstep.translator.Type;

import std.stdio;

class Record (Data) : Declaration
{
    static bool[Cursor] recordDefinitions;

    this (Cursor cursor, Cursor parent, Translator translator)
    {
        super(cursor, parent, translator);
    }

    private bool inBitField = false;
    private uint currentBitWidth = 0;
    private string bitFieldText = "";

    private void terminateBitField(Data context)
    {
        auto padding = 0;
        if (currentBitWidth < 8 && currentBitWidth > 0) {
            padding = 8 - currentBitWidth;
        }

        if (currentBitWidth < 16 && currentBitWidth > 8) {
            padding = 16 - currentBitWidth;
        }

        if (currentBitWidth < 32 && currentBitWidth > 16) {
            padding = 32 - currentBitWidth;
        }

        if (currentBitWidth < 64 && currentBitWidth > 32) {
            padding = 64 - currentBitWidth;
        }

        if (padding) {
            bitFieldText ~= ", uint, \"__padding\", " ~ to!string(padding);
        }

        bitFieldText ~= "));";
        context.instanceVariables ~= bitFieldText;
        currentBitWidth = 0;
        inBitField = false;
    }
    private auto handleBitField(Cursor cursor, Data context)
    {
        if (!cursor.isBitField() && inBitField) {
            terminateBitField(context);
            return false;
        }

        if (!cursor.isBitField() && !inBitField) {
            return false;
        }

        if (cursor.isBitField() && !inBitField) {
            bitFieldText = "mixin(bitfields!(";
        }

        inBitField = true;
        if (currentBitWidth) {
            bitFieldText ~= ", ";
        }

        currentBitWidth += cursor.getBitFieldWidth();
        auto fieldName = cursor.spelling;
        if (!fieldName.isPresent()) {
            fieldName = "__padding_" ~ to!string(currentBitWidth);
        }

        bitFieldText ~= translateType(cursor.type) ~ ", \"" ~ fieldName ~ "\", " ~ to!string(cursor.getBitFieldWidth);
        return true;
    }

    override string translate ()
    {
        return writeRecord(spelling, (context) {
            foreach (cursor, parent ; cursor.declarations)
            {
                with (CXCursorKind)
                    switch (cursor.kind)
                    {
                    case CXCursor_FieldDecl:
                        auto bitfield = handleBitField(cursor, context);
                        if (!bitfield) {
                            translateVariable(cursor, context);
                        }
                        break;

                    case CXCursor_UnionDecl:
                    case CXCursor_StructDecl:
                        translateStructDecl(cursor, context);
                        default: break;
                    }
            }

            if (inBitField) {
                terminateBitField(context);
            }
        });
    }

private:

    string writeRecord (string name, void delegate (Data context) dg)
    {
        auto context = new Data;

        if (cursor.isDefinition)
            this.recordDefinitions[cursor] = true;
        else
            context.isFwdDeclaration = true;

        context.name = translateIdentifier(name);

        dg(context);

        return context.data;
    }

    void translateStructDecl (Cursor cursor, Data context)
    {
        output.newContext();
        context.instanceVariables ~= translator.translate(cursor);
    }

    void translateVariable (Cursor cursor, Data context)
    {
        output.newContext();
        context.instanceVariables ~= translator.variable(cursor);
    }
}
