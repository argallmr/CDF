; docformat = 'rst'
;
; NAME:
;       MrCDF_Attribute__Define
;
;*****************************************************************************************
;   Copyright (c) 2014, Matthew Argall                                                   ;
;   All rights reserved.                                                                 ;
;                                                                                        ;
;   Redistribution and use in source and binary forms, with or without modification,     ;
;   are permitted provided that the following conditions are met:                        ;
;                                                                                        ;
;       * Redistributions of source code must retain the above copyright notice,         ;
;         this list of conditions and the following disclaimer.                          ;
;       * Redistributions in binary form must reproduce the above copyright notice,      ;
;         this list of conditions and the following disclaimer in the documentation      ;
;         and/or other materials provided with the distribution.                         ;
;       * Neither the name of the <ORGANIZATION> nor the names of its contributors may   ;
;         be used to endorse or promote products derived from this software without      ;
;         specific prior written permission.                                             ;
;                                                                                        ;
;   THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY  ;
;   EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES ;
;   OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT  ;
;   SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,       ;
;   INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED ;
;   TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR   ;
;   BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN     ;
;   CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN   ;
;   ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH  ;
;   DAMAGE.                                                                              ;
;*****************************************************************************************
;
; PURPOSE:
;+
;       This is class for parsing attribute information from CDF files. It is used as
;       a utility routine for the CDF_File object.
;
;       Information about CDF files can be found at the following site::
;           - `<User's Guide http://ppi.pds.nasa.gov/doc/cdf/CDF34-Users-Guide.pdf>`
;           - `<ISTP Guide http://spdf.gsfc.nasa.gov/istp_guide/istp_guide.html>`
;           - `<Offial IDL Patch http://cdaweb.gsfc.nasa.gov/pub/software/cdf/dist/cdf34_1/idl/>`
;           - `<CDF Home Page http://cdf.gsfc.nasa.gov/>`
;           - `<About Leap Seconds http://cdf.gsfc.nasa.gov/html/leapseconds.html>`
;
; :Categories:
;       CDF Utilities, File I/O
;
; :Uses:
;   Uses the following external programs::
;       cgErrorMsg.pro
;       LinkedList__Define (Coyote Graphics)
;
; :Author:
;   Matthew Argall::
;       University of New Hampshire
;       Morse Hall, Room 113
;       8 College Rd.
;       Durham, NH, 03824
;       matthew.argall@wildcats.unh.edu
;
; :History:
;   Modification History::
;       2014/03/07  -   Written by Matthew Argall
;       2014/03/22  -   The GetValue works. Removed the VALUE and DATATYPE properties.
;                           Added the _OverloadPrint method. No longer get the value
;                           and type within the ParseAttribute method. - MRA
;       2014/03/31  -   Removed all variable-related properties and the parse method,
;                           since variable attributes are associated with more than one
;                           variable. Added the ENTRYMASK to the Get*Value methods. - MRA
;-
;*****************************************************************************************
;+
;   Provide information when the PRINT procedure is called.
;-
function MrCDF_Attribute::_OverloadPrint
    on_error, 2
    
    ;Get the entry information
    entryMask = self -> GetEntryMask(CDF_TYPE=cdf_type, MAXGENTRY=maxGEntry, NUMGENTRIES=numGEntries)
    
    nameStr     = string('Name:',        self.name,   FORMAT='(a-23, a0)')
    numberStr   = string('Number:',      self.number, FORMAT='(a-20, i0)')
    scopeStr    = string('Scope:',       self.scope,  FORMAT='(a-20, a0)')
    maxEntryStr = string('Max Entry:',   maxGEntry,   FORMAT='(a-20, i0)')
    numEntryStr = string('Num Entries:', numGEntries, FORMAT='(a-20, i0)')
    typeStr     = string('CDF Type:', "['" + strjoin(cdf_type, "', '") + "']", FORMAT='(a-20, a0)')
    maskStr     = string('Entry Mask:', '[' + strjoin(string(entryMask, FORMAT='(i1)'), ', ') + ']', FORMAT='(a-20, a0)')
    
    ;Append all of the strings together. Make a column so each is
    ;printed on its own line.
    output = [[nameStr], $
              [numberStr], $
              [scopeStr], $
              [maxEntryStr], $
              [numEntryStr], $
              [typeStr], $
              [maskStr]]
    
    ;Offset everything form the name
    output[0,1:*] = '   ' + output[0,1:*]
    
    return, output
end


;+
;   Create a mask for the global entry numbers (gEntryNums) associated with a global
;   attribute. Global attribute values are array-like and are indexed by gEntryNums.
;   However, values do not need to exist at all gEntryNum. This method creates a mask
;   of 1s and 0s indicated if a value exists at the corresponding gEntryNum.
;
; :Keywords:
;       MAXGENTRY:          in, optional, type=long
;                           Highest global entry index associated with the attribute.
;       NUMGENTRIES:        in, optional, type=long
;                           Number of global entries associated with the attribute. Can
;                               be less than `MAXGENTRY`+1.
;
; :Returns:
;       ATTRVALUE:          Value(s) of the attribute.
;-
function MrCDF_Attribute::GetEntryMask, $
CDF_TYPE=cdf_type, $
MAXGENTRY=maxGEntry, $
MAXRENTRY=maxREntry, $
MAXZENTRY=maxZEntry, $
NUMGENTRIES=numGEntries, $
NUMRENTRIES=numREntries, $
NUMZENTRIES=numZEntries
    on_error, 2
    
    ;Get the CDF file ID
    fileID = self.parent -> GetFileID()
    if arg_present(cdf_type) then doCDFType=1

;-----------------------------------------------------
; Global Attribute \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
;-----------------------------------------------------
    if self.global then begin
        ;Get entry information
        cdf_control, fileID, ATTRIBUTE=self.name, GET_ATTR_INFO=attr_info
        numGEntries = attr_info.numGEntries
        maxGEntry   = attr_info.maxGEntry
        
        ;Build the mask
        entryMask = bytarr(maxGEntry+1)
        gAttrCount = 0L
        if doCDFType then cdf_type  = strarr(maxGEntry+1)
        
        ;Step through each entry
        for thisGEntry = 0, maxGEntry do begin
            tf_exists = cdf_attexists(fileID, self.name, thisGEntry)
            
            ;Does the attribute entry exist?
            if tf_exists then begin
                ;Get the CDF type?
                if doCDFType then begin
                    cdf_attget, fileID, self.name, thisGEntry, value, CDF_TYPE=type
                    cdf_type[gAttrCount]  = type
                endif
                
                ;Unmask the value
                entryMask[thisGEntry] = 1B
                gAttrCount++
            endif
        endfor
        
        ;Trim results
        if doCDFType then cdf_type = cdf_type[0:gAttrCount-1]
        
        ;Check that all were found
        if gAttrCount ne numGEntries then message, 'Not all global entries were found.', /INFORMATIONAL
;-----------------------------------------------------
; Variable Attribute \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
;-----------------------------------------------------
    endif else begin
        message, 'Variable entry mask not implemented yet.'
    endelse
    
    return, entryMask
end


;+
;   Return the CDF attribute name.
;
; :Returns:
;       ATTRNAME:           CDF attribute name.
;-
function MrCDF_Attribute::GetName
    return, self.name
end


;+
;   Return the CDF attribute number.
;
; :Returns:
;       ATTRNUM:            CDF attribute number.
;-
function MrCDF_Attribute::GetNumber
    return, self.number
end


;+
;   Return the value of the attribute.
;
;   NOTES:
;       - Attribute values must be scalars (i.e. at most one value per entry number).
;       - Attribute values can be of different types.
;       - Entry numbers can be skipped.
;
; :Params:
;       ENTRYNUM:           in, out, optional, type=long/longarr
;                           If an index or index array is given, then they correspond to
;                               the global entry numbers whose values are to be retrieved.
;                               If named variable is provided, the global entry numbers
;                               all entries containing values will be returned. Values may
;                               be stored at discontiguous entry numbers.
;
; :Keywords:
;       CDF_TYPE:           out, optional, type=string
;                           CDF datatype of `ATTRVALUE`. Not all attribute values need
;                               to be of the same datatype.
;       ENTRYMASK:          out, optional, type=bytarr
;                           An array of 1's and 0's indicating whether or not a value
;                               has been written to the global entry number corresponding
;                               to a given array index. Attribute values do not have to
;                               be contiguous. If `ENTRYNUM` was provided, ENTRYMASK will
;                               correspond only to those entry numbers given.
;
; :Returns:
;       ATTRVALUE:          out, required, type=object/array
;                           Value(s) of the attribute. If a value does not exist at a
;                               particular entry number, it will be skipped
;                               (see `ENTRYMASK`). Global attribute values do not have to
;                               be the same type. If they are not, a "LinkedList" object
;                               will be returned instead of an array.
;-
function MrCDF_Attribute::GetGlobalAttrValue, entryNum, $
CDF_TYPE=cdf_type, $
ENTRYMASK=entryMask, $
ZVARIABLE=zvariable
    on_error, 2
    
    ;Get the CDF file ID
    fileID = self.parent -> GetFileID()
    nEntryNum = n_elements(entryNum)
    
    ;Create a linked list for the values
    attrValueList = obj_new('LinkedList')

;-----------------------------------------------------
; Specific Entries \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
;-----------------------------------------------------
    if nEntryNum gt 0 then begin
        cdf_type  = strarr(nEntryNum)
        entryMask = bytarr(nEntryNum)
    
        ;Step through each entry
        for i = 0, nEntryNum-1 do begin
            ;Make sure the entry number exists
            if cdf_attexists(fileID, self.name, i) eq 0 then $
                message, 'Entry number: ' + strtrim(i, 2) + ' does not exist ' + $
                         'for global attribute "' + self.name + '".'
            
            ;Get the value
            cdf_attget, fileID, self.name, i, value, CDF_TYPE=type
            
            ;Store the value and type
            attrValueList -> Add, value
            cdf_type[i]    = type
            entryMask      = 1B
        endfor

;-----------------------------------------------------
; All Entries \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
;-----------------------------------------------------
    endif else begin
        ;Get entry information
        cdf_control, fileID, ATTRIBUTE=self.name, GET_ATTR_INFO=attr_info
        nEntries   = attr_info.maxGEntry+1
        cdf_type   = strarr(nEntries)
        entryNum   = lindgen(nEntries)
        gEntryMask = bytarr(nEntries)
    
        gAttrCount = 0
        gIndex = 0
        while (gAttrCount lt attr_info.numGEntries) && (gIndex le attr_info.maxGEntry) do begin
            thisGEntry = entryNum[gIndex]
    
            ;Check if there is a value at this entry
            if cdf_attexists(fileID, self.name, thisGEntry) eq 0 then begin
                gIndex++
                continue
            endif
        
            ;Get the value
            cdf_attget, fileID, self.name, thisGEntry, value, CDF_TYPE=type

            ;Store the value and type
            gEntryMask[gIndex]   = 1B
            attrValueList        -> Add, value
            cdf_type[gAttrCount] = type
            entryNum[gAttrCount] = gIndex
            gAttrCount++
            gIndex++
        endwhile
        
        ;Trim results
        if gAttrCount ne nEntries then begin
            cdf_type  = cdf_type[0:gAttrCount-1]
            entryNum  = entryNum[0:gAttrCount-1]
        endif
    endelse
    
    ;How many values were stored?
    nValues = attrValueList -> Get_Count()
    
    ;Return a scalar?
    if nValues eq 1 then begin
        attrValue = attrValueList -> Get_Item(0)
        cdf_type  = cdf_type[0]
        entryNum  = entryNum[0]
        entryMask = entryMask[0]
        
    ;Return an array or a list?
    endif else begin
        ;Return an array if all of the CDF_TYPEs are the same
        if min(cdf_type eq cdf_type[0]) eq 1 then begin
            attrValue = attrValueList -> Get_Item(/ALL)
            obj_destroy, attrValueList
        endif else begin
            attrValue = attrValueList
        endelse
    endelse
    
    return, attrValue
end


;+
;   Return the value of the attribute.
;
; :Params:
;       VARNAME:            in, out, optional, type=long/longarr
;                           Name of the variable for which the attribute value is to be
;                               returned.
;
; :Keywords:
;       CDF_TYPE:           out, optional, type=string
;                           CDF datatype of `ATTRVALUE`. Posibilities are: 'CDF_BYTE',
;                               'CDF_CHAR', 'CDF_DOUBLE', 'CDF_REAL8', 'CDF_EPOCH', 
;                               'CDF_LONG_EPOCH', 'CDF_FLOAT', 'CDF_REAL4', 'CDF_INT1',
;                               'CDF_INT2', 'CDF_INT4', 'CDF_UCHAR', 'CDF_UINT1',
;                               'CDF_UINT2', 'CDF_UINT4' or 'UNKNOWN'.
;
; :Returns:
;       ATTRVALUE:          Value(s) of the attribute.
;-
function MrCDF_Attribute::GetVarAttrValue, varName, $
CDF_TYPE=cdf_type
    on_error, 2
    
    ;Get the CDF file ID
    fileID = self.parent -> GetFileID()

    ;Get the value -- STATUS will be 0 if SELF is a global attribute or if the
    ;                 variable does not contain the attribute.
    cdf_attget_entry, fileID, self.name, varName, attrEntryType, attrValue, status, $
                      CDF_TYPE=cdf_type, ZVARIABLE=zvariable

    ;Message if the value could not be retrieved.
    if status eq 0 then $
        message, 'Variable ' + varName + ' does not have attribute "' + self.name + '".'
    
    return, attrValue
end


;+
;
; :Keywords:
;       NAME:           in, optional, type=string
;                       CDF attribute name.
;       NUMBER:         in, optional, type=integer
;                       CDF attribute number.
;       DATATYPE:       out, optional, type=string
;                       CDF data type. Posibilities are: 'CDF_BYTE',
;                           'CDF_CHAR', 'CDF_DOUBLE', 'CDF_REAL8', 'CDF_EPOCH', 
;                           'CDF_LONG_EPOCH', 'CDF_FLOAT', 'CDF_REAL4', 'CDF_INT1',
;                           'CDF_INT2', 'CDF_INT4', 'CDF_UCHAR', 'CDF_UINT1',
;                           'CDF_UINT2', 'CDF_UINT4'.
;       GLOBAL:         out, optional, type=boolean
;                       1 if the attribute is global in scope. 0 for variable scope.
;       SCOPE:          out, optional, type=string
;                       Scope of the attribute. Possibilities are "GLOBAL_SCOPE",
;                           "GLOBAL_SCOPE_ASSUMED", "VARIABLE_SCOPE", and
;                           "VARAIBLE_SCOPE_ASSUMED".
;       VALUE:          out, optional, type=any
;                       Value of the attribute.
;-
pro MrCDF_Attribute::GetProperty, $
NAME=name, $
NUMBER=number, $
TYPE=type, $
DATATYPE=datatype, $
GLOBAL=global, $
SCOPE=scope, $
VALUE=value
    compile_opt strictarr
    on_error, 2
    
    ;Get Properties
    if arg_present(name)     then name     =  self.name
    if arg_present(number)   then number   =  self.number
    if arg_present(type)     then type     =  self.type
    if arg_present(datatype) then datatype =  self.datatype
    if arg_present(global)   then global   =  self.global
    if arg_present(scope)    then scope    =  self.scope
    if arg_present(value)    then value    = *self.value
end


;+
;   The purpose of this method is to parse a global attribute from a CDF file.
;-
pro MrCDF_Attribute::ParseGlobalAttribute
    compile_opt strictarr
    
    ;Error handling
    catch, the_error
    if the_error ne 0 then begin
        catch, /cancel
        void = cgErrorMsg()
        return
    endif
    
    ;inquire about the attribute to get its name and scope
    parentID = self.parent -> GetFileID()
    attrNum  = cdf_attnum(parentID, self.name)
    cdf_attinq,  parentID, self.name, attrName, attrScope, maxREntry, maxZEntry
    cdf_control, parentID, ATTRIBUTE=attrNum, GET_ATTR_INFO=attr_info
    
    ;Global Attribute?
    if attr_info.numgentries gt 0 then begin
        if self.global eq 0 || strpos(attrScope, 'GLOBAL') eq -1 then $
            message, 'Inconsistency: Attribute "' + attname + '" not global.', /INFORMATIONAL

        ;Get each global attribute value
        for gEntryNum = 0, attr_info.numgentries-1 do begin
            ;Make sure the gEntry exists (they can be skipped)
            if cdf_attexists(parentID, attrName, gEntryNum) eq 0 then continue
            
            ;Get the gEntry value
            cdf_attget, parentID, attrNum, gEntryNum, value, CDF_TYPE=cdf_type
            
            ;Allocate memory to the result
            if gEntryNum eq 0 then $
                attrValue = make_array(n_elements(value), attr_info.numgentries, TYPE=size(value, /TYPE))
            
            ;Store the value
            attrValue[*, gEntryNum] = value
        endfor
    endif

    ;Attributes can be defined without having any data.
    if n_elements(cdf_type) gt 0 then begin
        if cdf_type eq 'CDF_CHAR' || cdf_type eq 'CDF_UCHAR' then attrValue = string(attrValue)
        self.datatype = cdf_type
        *self.value = attrValue
    endif
    
    ;Make a data structure of the attribute information
    self.number = attrNum
    self.scope  = attrScope
end


;+
;   The purpose of this method is to parse an attribute from a CDF file.
;-
pro MrCDF_Attribute::ParseVariableAttribute
    compile_opt strictarr
    
    ;Error handling
    catch, the_error
    if the_error ne 0 then begin
        catch, /cancel
        void = cgErrorMsg()
        return
    endif
    
    ;inquire about the attribute to get its name and scope
    parentID = self.parent -> GetFileID()
    attnum   = cdf_attnum(parentID, self.name)
    cdf_attinq,  parentID, self.name, attname, scope, maxREntry, maxZEntry
    cdf_control, parentID, ATTRIBUTE=attnum, GET_ATTR_INFO=att_info

    ;Variable Attribute
    varinq = cdf_varinq(parentID, self.varname)
    cdf_attget_entry, parentID, attname, self.varname, attType, attValue, status, $
                      CDF_TYPE=cdf_type, ZVARIABLE=varInq.is_zvar
    if status eq 0 then message, 'Attribute "' + attname + '" does not exist for variable "' + self.varname + '".'

    ;Convert bytes back to strings.
    if n_elements(cdf_type) eq 0 then stop
    if cdf_type eq 'CDF_CHAR' || cdf_type eq 'CDF_UCHAR' then attValue = string(attValue)
    
    ;Make a data structure of the attribute information
    self.number   = attnum
    self.scope    = scope
end


;+
;   Clean up after the object is destroyed
;-
pro MrCDF_Attribute::cleanup
    ;Nothing to clean up
end


;+
;   The initialization method.
;
; :Params:
;       ATTRNAME:           in, required, type=string
;                           CDF attribute name found in `PARENT`.
;       PARENT:             in, required, type=object
;                           CDF_File object
;-
function MrCDF_Attribute::init, attrName, parent
    compile_opt strictarr
    
    ;Error handling
    catch, the_error
    if the_error ne 0 then begin
        catch, /cancel
        void = cgErrorMsg()
        return, 0
    endif

    ;Check Inputs
    if MrIsA(attrName, /SCALAR, 'STRING') eq 0 then $
        message, 'AttrName must be a scalar string.'
    
    if MrIsA(parent, /SCALAR, 'OBJREF') eq 0 then $
        message, 'PARENT must be a scalar object.'
    
    ;Get attribute info
    parentID = parent -> GetFileID()
    cdf_attinq,  parentID, attrName, theName, attrScope, maxEntry, maxZEntry
    
    ;Set properties
    self.name   = attrName
    self.parent = parent
    self.scope  = attrScope
    if strpos(attrScope, 'GLOBAL') ne -1 $
        then self.global = 1B $
        else self.global = 0B
    
    return, 1
end


;+
;   The class definition.
;
; :Hidden:
;
; :Fields:
;       GLOBAL:         Indicates the attribute is global in scope (not variable).
;       NAME:           CDF attribute name.
;       NUMBER:         CDF attribute number.
;       PARENT:         CDF_File object.
;       SCOPE:          Scope of the attribute.
;-
pro MrCDF_Attribute__define
    compile_opt strictarr
    
    define = { MrCDF_Attribute, $
               global:    0B, $
               name:      '', $
               number:    0L, $
               parent:    obj_new(), $
               scope:     '' $
             }
end