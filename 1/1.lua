function output(constructors)
  for i, constr in pairs(constructors) do
    io.write(constr.name)
    if #constr.greater > 0 then
      io.write(" < {")
      output(constr.greater)
      io.write("}")
    end
    if i ~= #constructors then
      io.write(", ")
    end
  end
end

function isVarInConstr(constr, var)
  for _, arg in pairs(constr.args) do
    if (arg.isVar and arg.name == var.name) or 
     (not arg.isVar and isVarInConstr(arg, var)) then
      return true
    end
  end
  return false
end

function termEq(term1, term2)
  if term1.name ~= term2.name then
    return false
  end
  if not term1.isVar then
    local argsNum = #term1.args
    for i = 1, argsNum do
      if not termEq(term1.args[i], term2.args[i]) then
        return false
      end
    end
  end
  return true
end

function law1(term1, term2)
  for _, arg in pairs(term1.args) do
    if termEq(arg, term2) then
      return true
    end
  end
  return false
end

function law2(term1, term2, constructors)
  for _, arg in pairs(term1.args) do
    if knuthBendix(arg, term2, constructors) then
      return true
    end
  end
  return false
end

function findConstr(name, constructors)
  for i, constr in ipairs(constructors) do
    if constr.name == name then
      return constr, constructors, i
    end
    local constrName, cParGr, cIndex = findConstr(name, constr.greater)
    if constrName then
      return constrName, cParGr, cIndex
    end
  end
end

function tieConstr(c1parGr, c1index, c1, c2Gr, wasInConstrList)
  table.insert(c2Gr, 1, c1)
  if wasInConstrList then
    table.remove(c1parGr, c1index)
  end
end

function untieConstr(c1parGr, c1index, c1, c2Gr, wasInConstrList)
  table.remove(c1parGr, c1index)
  if wasInConstrList then
    table.insert(c2Gr, c1)
  end
end

function law3(term1, term2, constructors)
  local constr1, c1parGr, c1index = findConstr(term1.name, constructors)
  local constr2 = findConstr(term2.name, constructors)
  if constr1 == constr2 then
    return false
  end
  if constr1 < constr2 then
    return false
  end
  local movedConstr = false
  if not (constr1 > constr2) then
    movedConstr = true
    tieConstr(c1parGr, c1index, constr1, constr2.greater, c1parGr == constructors)
  end
  for _, arg in ipairs(term2.args) do
    if not knuthBendix(term1, arg, constructors) then
      if movedConstr then
        untieConstr(constr2.greater, 1, constr1, c1parGr, c1parGr == constructors)
      end
      constructors = constrCopy
      return false
    end
  end
  return true
end

function law4(term1, term2, constructors, orderStr)
  if term1.name ~= term2.name then
    return false
  end
  for _, arg in ipairs(term2.args) do
    if not knuthBendix(term1, arg, constructors, orderStr) then
      return false
    end
  end
  local s, e, d
  if orderStr == "lexicographic" then
    s, e, d = 1, #term1.args, 1
  else
    s, e, d = #term1.args, 1, -1
  end
  for i = s, e, d do
    local arg1 = term1.args[i]
    local arg2 = term2.args[i]
    if not termEq(arg1, arg2) then
      return knuthBendix(arg1, arg2, constructors, orderStr)
    end
  end
  return false
end

function knuthBendix(term1, term2, constructors, orderStr) 
  if term1.isVar then
    return false
  else
    if term2.isVar then
      return isVarInConstr(term1, term2)
    else
      return law4(term1, term2, constructors, orderStr) or law1(term1, term2)
       or law2(term1, term2, constructors) or law3(term1, term2, constructors)
    end
  end
end

function findArgsStr(termStr, i)
  local iStart = i
  local ch = 1
  while ch > 0 do
    local char = termStr:sub(i, i)
    if char == "(" then
      ch = ch + 1
    elseif char == ")" then
      ch = ch - 1
    end
    i = i + 1
  end
  return termStr:sub(iStart, i-2), i
end

function findConstructorArity(char, constructors)
  local constructorsNum = #constructors
  for i = 1, constructorsNum do
    if constructors[i].name == char then
      return constructors[i].arity
    end
  end
  return nil
end

function isInTable(char, variables)
  local variablesNum = #variables
  for i = 1, variablesNum do
    if variables[i] == char then
      return true
    end
  end
  return false
end

function parseTerm(termStr, constructors, variables, arity)
  local term = {}
  local termStrLen = #termStr
  local i, argsNum = 1, 0
  while i <= termStrLen do
    local char = termStr:sub(i, i)
    if isInTable(char, variables) then
      table.insert(term, {
      	 name = char,
        isVar = true
      })
      argsNum = argsNum + 1
    else
      local arity = findConstructorArity(char, constructors)
      if arity then
        local argsStr
        argsStr, i = findArgsStr(termStr, i + 2)
        table.insert(term, {
          name = char,
          isVar = false,
          args = parseTerm(argsStr, constructors, variables, arity)
        })
        argsNum = argsNum + 1
      elseif char ~= "," and char ~= " " then
        io.write(char, " error in term name\n")
        os.exit()
      end
    end
    i = i + 1
  end
  if arity and arity ~= argsNum then
    io.write("error in term arity\n")
    os.exit()
  end
  return term
end

function makeRules(rulesNum, rulesStr, constructors, variables)
  local rules = {}
  for i = 1, rulesNum do
    local ruleStr = rulesStr[i]
    local eq = ruleStr:find("=")
    rules[i] = {
      term1 = parseTerm(ruleStr:sub(1, eq-1), constructors, variables)[1],
      term2 = parseTerm(ruleStr:sub(eq+1, #ruleStr), constructors, variables)[1]
    }
  end
  return rules
end

function makeVariables(variablesStr)
  local variables = {}
  local i = variablesStr:find("=") + 1
  while true do
    i = variablesStr:find("%a", i+1)
    if not i then break end
    table.insert(variables, variablesStr:sub(i, i))
  end
  return variables
end

function makeConstructors(constructorsStr)
  local constructors = {}
  local first, last = 0, 0
  local metaConstr = {
    __eq = function (a, b)
      return a.name == b.name
    end,
    __lt = function (a, b)
      for _, constr in ipairs(a.greater) do
        if constr <= b then
          return true
        end
      end
      return false
    end,
    __le = function (a, b)
      return a == b or a < b
    end
  }
  while true do
    first, last = constructorsStr:find("%a[(]%d+[)]", first+1)
    if not first then break end
    local constr = {
      name = constructorsStr:sub(first, first),
      arity = tonumber(constructorsStr:sub(first+2, last-1)),
      greater = {}
    }
    setmetatable(constr, metaConstr)
    table.insert(constructors, constr)
  end
  return constructors
end

function input()
  io.write("Enter order\n")
  local orderStr = io.read()
  io.write("Enter constructors\n")
  local constructorsStr = io.read()
  io.write("Enter variables\n")
  local variablesStr = io.read()
  io.write("Enter rules num\n")
  local rulesNum = io.read()
  io.write("Enter rules\n")
  local rulesStr = {}
  for i = 1, rulesNum do
    rulesStr[i] = io.read()
  end
  return orderStr, constructorsStr, variablesStr, rulesNum, rulesStr
end

function main()
  local orderStr, constructorsStr, variablesStr, rulesNum, rulesStr = input()
  if orderStr ~= "lexicographic" and orderStr ~= "anti-lexicographic" then
    io.write("wrong order\n")
    os.exit()
  end
  local constructors = makeConstructors(constructorsStr)
  local variables = makeVariables(variablesStr)
  local rules = makeRules(rulesNum, rulesStr, constructors, variables)
  for i = 1, rulesNum do
    if not knuthBendix(rules[i].term1, rules[i].term2, constructors, orderStr) then
      io.write("rule #", i, " doesn\'t work\n")
      os.exit()
    end
  end
  output(constructors)
  io.write("\n")
end

main()