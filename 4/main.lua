function findNtermByRules(rules, ntermRules)
    for locNterm, locNtermRules in pairs(rules) do
        if #ntermRules == #locNtermRules then
            local neededNterm = true
            for _, rule in ipairs(ntermRules) do
                if not hasRuleIn(locNtermRules, rule) then
                    neededNterm = false
                end
            end
            if neededNterm then
                return locNterm
            end
        end
    end
    return nil
end

function getRulePostfix(rule, startI)
    local rulePostfix = {}
    
    local ruleLen = #rule
    for i = startI, ruleLen do
        table.insert(rulePostfix, rule[i])
    end

    return rulePostfix
end

function findSameRulePrefix(rule1, rule2)
    local sameRulePrefix = {}
    local minRuleLen = (#rule1 > #rule2) and #rule2 or #rule1
    for i = 1, minRuleLen do
        local smth1 = rule1[i]
        local smth2 = rule2[i]
        if type(smth1) ~= type(smth2) then
            return sameRulePrefix
        else
            if type(smth2) == "string" then
                if smth1 == smth2 then
                    table.insert(sameRulePrefix, smth1)
                else
                    return sameRulePrefix
                end
            else
                if smth1[1] == smth2[1] then
                    table.insert(sameRulePrefix, { smth1[1] })
                else
                    return sameRulePrefix
                end
            end
        end
    end
    return sameRulePrefix
end

function addingLeftContext(rules)
    -- новосозданные нетерминалы могут попасться в этом цикле, но они не помешают
    for nterm, ntermRules in pairs(rules) do
        local numRules = #ntermRules
        local i = 1
        while i <= numRules do
            local rule1 = ntermRules[i]
            local j = i + 1
            while j <= numRules do
                local rule2 = ntermRules[j]
                local sameRulePrefix = findSameRulePrefix(rule1, rule2)
                if (#rule1 == #sameRulePrefix) and (#rule1 == #rule2) then
                    table.remove(ntermRules, j)
                    numRules = numRules - 1
                elseif #sameRulePrefix ~= 0 then
                    local newRule1 = getRulePostfix(rule1, #sameRulePrefix + 1)
                    local newRule2 = getRulePostfix(rule2, #sameRulePrefix + 1)

                    local newNtermRules = {}
                    table.insert(newNtermRules, newRule1)
                    table.insert(newNtermRules, newRule2)
                    local newNterm = findNtermByRules(rules, newNtermRules)
                    if not newNterm then
                        newNterm = makeNewNterm(rules)
                        rules[newNterm] = newNtermRules
                    end

                    table.insert(sameRulePrefix, { newNterm })
                    ntermRules[i] = sameRulePrefix

                    table.remove(ntermRules, j)
                    numRules = numRules - 1
                else
                    j = j + 1
                end
            end
            i = i + 1
        end
    end
end

function parseTreeToTermStr(parseTree)
    if type(parseTree) == "string" then
        return parseTree
    end
    local termStr = ""
    for _, smth in ipairs(parseTree.next) do
        termStr = termStr..parseTreeToTermStr(smth)
    end
    return termStr
end

function buildASTApproximation(parseTree, finiteLangNterms)
    local finNext = {}
    local notFinNextNterms = {}
    local notFinNextNterPos
    local nextNum = #(parseTree.next)
    for i, smth in ipairs(parseTree.next) do
        if type(smth) == "table" then
            if finiteLangNterms[smth.nterm] then
                table.insert(finNext, smth)
            else
                table.insert(notFinNextNterms, smth)
                notFinNextNterPos = i
            end
        else
            table.insert(finNext, smth)
        end
    end

    --Если потомки узла были построены по правилу A → T (где T —
    --  единственный нетерминал), то сразу же заменяем метку узла (с A)
    --  на результат разбора его потомка.
    if nextNum == 1 then
        local next = parseTree.next[1]
        parseTree.nterm = parseTreeToTermStr(next)
        return
    end

    --Если потомки узла были построены по правилу A → Φ, где в Φ
    --  все нетерминалы имеют конечный язык, тогда просто заменяем
    --  метку узла A на терминальную строку, в которую он был разобран.
    if #notFinNextNterms == 0 then
        parseTree.nterm = parseTreeToTermStr(parseTree)
        return
    end 

    --Если потомки узла были построены по правилу A → T1T2 (где T1
    --  имеет конечный язык, а T2 нет), то заменяем метку узла A на
    --  результат разбора T1, и рекурсивно продолжаем преобразование в
    --  потомке T2. Аналогично, если A → T2T1.
    if nextNum == 2 then
        parseTree.nterm = parseTreeToTermStr(finNext[1])
        buildASTApproximation(notFinNextNterms[1], finiteLangNterms)
        return
    end

    --Если потомки узла были построены по правилу A → T1T2T3, где
    --  один из Ti, скажем, T1 имеет конечный язык, а два нет, то заменяем
    --  метку узла A на результат разбора T1, и рекурсивно продолжаем
    --  преобразование в потомках T2 и T3.
    if #finNext == 1 then
        parseTree.nterm = parseTreeToTermStr(finNext[1])
        buildASTApproximation(notFinNextNterms[1], finiteLangNterms)
        buildASTApproximation(notFinNextNterms[2], finiteLangNterms)
        return
    end

    --Если применялось правило A → T1T2T3, где T2 имеет бесконечный
    --  язык, а T1 и T3 конечный, тогда заменяем метку A на разбор T1,
    --  полагая ему два потомка: T2 и T3, в которых продолжаем
    --  преобразование.
    if notFinNextNterPos == 2 then
        parseTree.nterm = parseTreeToTermStr(finNext[1])
        table.remove(parseTree.next, 1)
        buildASTApproximation(notFinNextNterms[1], finiteLangNterms)
        if type(finNext[2]) == "table" then
            buildASTApproximation(finNext[2], finiteLangNterms)
        end
        return
    end

    --В противном случае, если два из трёх нетерминалов в правиле
    --  имеют конечные языки, то они стоят рядом, и меткой вместо A
    --  полагаем конкатенацию их разбора (оставляя только одного
    --  потомка).
    parseTree.nterm = parseTreeToTermStr(finNext[1])..parseTreeToTermStr(finNext[2])
    table.remove(parseTree.next, 2)
    if notFinNextNterms == 1 then
        table.remove(parseTree.next, 3)
    else
        table.remove(parseTree.next, 1)
    end
end

function copy(obj, seen)
    if type(obj) ~= 'table' then
        return obj
    end
    if seen and seen[obj] then
        return seen[obj]
    end
    local s = seen or {}
    local res = setmetatable({}, getmetatable(obj))
    s[obj] = res
    for k, v in pairs(obj) do
        res[copy(k, s)] = copy(v, s)
    end
    return res
end

function outputParseTree(parseTree, spaces)
    if not spaces then
        spaces = ""
    end

    local wasTree = false
    local prevTree = false
    local newSpaces = spaces.."  "
    
    io.write(spaces.."<"..parseTree.nterm.."> -> {")
    for _, smth in ipairs(parseTree.next) do
        if type(smth) == "string" then
            if prevTree then
                io.write(newSpaces)
            end
            io.write(smth.." ")
            prevTree = false
        else
            if not prevTree then
                io.write("\n")
            end
            outputParseTree(smth, newSpaces)
            wasTree = true
            prevTree = true
        end
    end
    if wasTree then
        if not prevTree then
            io.write("\n")
        end
        io.write(spaces)
    end
    io.write("}\n")
end

function ntermHasFiniteLangStep(rules, visitedNterms, nterm)
    local newVisitedNterms = {}
    for _, rule in ipairs(rules[nterm]) do
        for _, smth in ipairs(rule) do
            if type(smth) == "table" then
                local ruleNterm = smth[1]
                if visitedNterms[ruleNterm] then
                    if not newVisitedNterms[ruleNterm] then
                        return false
                    end
                else
                    visitedNterms[ruleNterm] = true
                    newVisitedNterms[ruleNterm] = true
                    if not ntermHasFiniteLangStep(rules, visitedNterms, ruleNterm) then
                        return false
                    end
                end
            end
        end
    end
    return true
end

function ntermHasFiniteLang(rules, nterm)
    local visitedNterms = {}
    visitedNterms[nterm] = true
    return ntermHasFiniteLangStep(rules, visitedNterms, nterm)
end

function checkIfGrammarIsGood(rules)
    local finiteLangNterms = {}
    local notFiniteLangNterms = {}
    for nterm, ntermRules in pairs(rules) do
        for _, rule in ipairs(ntermRules) do
            if #rule == 0 or #rule > 3 then
                return false
            end

            local ruleNterms = {}
            for _, smth in ipairs(rule) do
                if type(smth) == "table" then
                    table.insert(ruleNterms, smth[1])
                end
            end

            if #rule == #ruleNterms then
                for _, ruleNterm in ipairs(ruleNterms) do
                    if finiteLangNterms[ruleNterm] then
                        goto continue
                    elseif not notFiniteLangNterms[ruleNterm] then
                        if ntermHasFiniteLang(rules, ruleNterm) then
                            finiteLangNterms[ruleNterm] = true
                            goto continue
                        else
                            notFiniteLangNterms[ruleNterm] = true
                        end
                    end
                end
                return false
            end
            ::continue::
        end
    end
    return true, finiteLangNterms
end

function ruleToStr(rule)
    local ruleStr = ""
    for _, smth in ipairs(rule) do
        if type(smth) == "table" then
            ruleStr = ruleStr.."["..smth[1].."]"
        else
            ruleStr = ruleStr..smth
        end
    end
    return ruleStr
end

function outputRules(rules, startNterm)
    io.write("--- Rules: ---\n")
    io.write("Start nterm: "..startNterm.."\n")
    for nterm, ntermRules in pairs(rules) do
        io.write("["..nterm.."] -> ")
        for i, rule in ipairs(ntermRules) do
            io.write(ruleToStr(rule))
            if (i ~= #ntermRules) then
                io.write(" | ")
            end
        end
        io.write("\n")
    end
    io.write("\n")
end

function input()
    local rules = {}
    for line in io.lines() do
        local first, last = 0, 0
        first, last = line:find("%[%a+%d*%]", 0)
        if not first then
            return rules, line
        end
        local startNterm = line:sub(first + 1, last - 1)
        if not rules[startNterm] then
           rules[startNterm] = {} 
        end
        local rule = {}

        first, last = line:find("->", last + 1)
        while true do
            first, last = line:find("[%||%[|%a|%d]", last + 1)
            if not first then break end
            local term = line:sub(first, last)
            if term == "|" then
                table.insert(rules[startNterm], rule)
                rule = {}
            elseif term == "[" then
                first, last = line:find("%a+%d*%]", first + 1)
                local nterm = line:sub(first, last - 1)
                table.insert(rule, {nterm})
            else
                table.insert(rule, term)
            end
        end
        table.insert(rules[startNterm], rule)
    end
end

function main()
    local rules, str = input()
    local startNterm = "S"
    local gramIsGood, finiteLangNterms = checkIfGrammarIsGood(rules)
    if not gramIsGood then
        io.write("The input grammar is not good\n")
        return
    end

    require("CYK_algorithm")
    local parseTree = CYKalgorithm(rules, startNterm, str)
    if not parseTree then
        io.write("The input string is not from the input language\n")
        return
    end

    --io.write(outputParseTree(parseTree)) -- для отладки
    buildASTApproximation(parseTree, finiteLangNterms)
    io.write("--- AST approximation ---\n")
    outputParseTree(parseTree)
    io.write("\n")

    require("eliminateLeftRec")
    eliminateLeftRec(rules, startNterm)
    addingLeftContext(rules)
    removeUnreachableNterms(rules, startNterm) -- иногда откуда-то берутся лишние, поэтому убираю
    outputRules(rules, startNterm)

    require("LL1grammarCheck")
    if grammarIsLL1(rules) then
        io.write("This grammar is LL(1)\n\n")
    else
        io.write("This grammar is not LL(1)\n\n")
    end

    gramIsGood, finiteLangNterms = checkIfGrammarIsGood(rules)
    if not gramIsGood then
        io.write("This grammar is not good\n")
        return
    end

    parseTree = CYKalgorithm(rules, startNterm, str)
    --io.write(outputParseTree(parseTree)) -- для отладки
    buildASTApproximation(parseTree, finiteLangNterms)
    io.write("--- AST approximation ---\n")
    outputParseTree(parseTree)
    io.write("\n")
end

main()