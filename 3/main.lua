function eqRules(rule1, rule2)
    if #rule1 ~= #rule2 then
        return false
    end
    for i, smth1 in ipairs(rule1) do
        local smth2 = rule2[i]
        if (type(smth1) ~= type(smth2)) then
            return false
        else
            if (type(smth1) == "table") then
                if (smth1[1] ~= smth2[1]) then
                    return false
                end
            else
                if (smth1 ~= smth2) then
                    return false
                end
            end
        end
    end
    return true
end

function hasRuleIn(rules, rule)
    for _, ruleInRules in ipairs(rules) do
        if eqRules(ruleInRules, rule) then
            return true
        end
    end
    return false
end

function addRule(rulesTo, rule)
    if not hasRuleIn(rulesTo, rule) then
        table.insert(rulesTo, rule) -- тут нет copy так что осторожней
    end
end

function addRules(rulesTo, rulesFrom)
    for _, rule in ipairs(rulesFrom) do
        addRule(rulesTo, rule)
    end
end

function makeFinalGrammar(grammars, newStartNterm1Part) 
    local GNFGrammar = {}

    for ntermGr, grammar in pairs(grammars) do
        for nterm, ntermRules in pairs(grammar) do
            local ntermN = nterm.."_"..ntermGr
            if not GNFGrammar[ntermN] then
                GNFGrammar[ntermN] = {}
            end
            local GNFNtermRules = GNFGrammar[ntermN]

            if nterm == newStartNterm1Part then
                local ntermRulesN = copy(ntermRules)
                for _, ntermRuleN in ipairs(ntermRulesN) do
                    if #ntermRuleN == 2 then
                        ntermRuleN[2][1] = ntermRuleN[2][1].."_"..ntermGr
                    end
                end
                --addRules(GNFNtermRules, ntermRulesN) -- походу нет смысла проверять на повторное вхождение
                for _, ntermRuleN in ipairs(ntermRulesN) do
                    table.insert(GNFNtermRules, ntermRuleN)
                end
            else
                for _, rule in ipairs(ntermRules) do
                    local locNterm = rule[1][1]
                    local locGrammar = grammars[locNterm]
                    for _, locRule in ipairs(locGrammar[newStartNterm1Part]) do
                        local locRuleN = copy(locRule)
                        if #locRuleN == 2 then
                            locRuleN[2][1] = locRuleN[2][1].."_"..locNterm
                        end
                        if #rule == 2 then
                            local locNtermRulePart = rule[2][1].."_"..ntermGr
                            table.insert(locRuleN, {locNtermRulePart})
                        end
                        --addRule(GNFNtermRules, locRuleN) -- походу нет смысла проверять на повторное вхождение
                        table.insert(GNFNtermRules, locRuleN)
                    end
                end
            end
        end
    end

    return GNFGrammar
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

function outputStateMachines(stateMachines)
    io.write("--- State Machines: ---\n")
    for nterm, stateMachine in pairs(stateMachines) do
        io.write("--- ".."["..nterm.."]".." state machine: ---\n")
        io.write("start state: "..stateMachine.startState.name.."\n")
        io.write("final state: "..stateMachine.finalState.name.."\n")
        for stateName, state in pairs(stateMachine.states) do
            for _, nextStateRule in ipairs(state.next) do
                io.write(stateName.." --("..ruleToStr(nextStateRule.rule)
                    ..")-> "..nextStateRule.state.name.."\n")
            end
        end
    end
    io.write("\n")
end

function makeGrammarsFromStateMachines(stateMachines)
    local grammars = {}
    for nterm, stateMachine in pairs(stateMachines) do
        local endStateHasNextStates = #stateMachine.finalState.next > 0
        local grammar = {}
        grammars[nterm] = grammar
        for stateName, state in pairs(stateMachine.states) do
            local rules = {}
            grammar[stateName] = rules
            for _, nextRuleState in ipairs(state.next) do
                if nextRuleState.state.name == stateMachine.finalState.name then
                    --addRule(rules, copy(nextRuleState.rule)) -- походу нет смысла проверять на повторное вхождение
                    table.insert(rules, copy(nextRuleState.rule))
                    if endStateHasNextStates then
                         -- походу нет смысла проверять на повторное вхождение
                        --addRule(rules, concatRules(nextRuleState.rule, {{nextRuleState.state.name}}))
                        table.insert(rules,  concatRules(nextRuleState.rule, {{nextRuleState.state.name}}))
                    end
                else
                     -- походу нет смысла проверять на повторное вхождение
                    --addRule(rules, concatRules(nextRuleState.rule, {{nextRuleState.state.name}}))
                    table.insert(rules,  concatRules(nextRuleState.rule, {{nextRuleState.state.name}}))
                end
            end
        end
    end
    return grammars
end

function reverseStateMachines(stateMachines)
    for nterm, stateMachine in pairs(stateMachines) do
        for stateName, state in pairs(stateMachine.states) do
            local nextStatesNum = #state.next
            local i = 1
            while i <= nextStatesNum do
                local nextStateRule = state.next[i]
                local locRule = nextStateRule.rule
                local locState = nextStateRule.state

                if nextStateRule.afterReverse then
                    nextStateRule.afterReverse = nil -- можно убрать метку
                    i = i + 1
                elseif stateName ~= locState.name then
                    table.insert(locState.next, {
                        afterReverse = true, -- помечаем переход как реверснутый
                        state = state,
                        rule = copy(locRule)
                    })
                    table.remove(state.next, i)
                    nextStatesNum = nextStatesNum - 1
                else
                    i = i + 1
                end
            end
        end

        local prevStartState = stateMachine.startState
        stateMachine.startState = stateMachine.finalState
        stateMachine.finalState = prevStartState
    end
end

function makeStateMachineRecStep(locStateMachine, nterm, rules)
    local ntermRules = rules[nterm]
    local locStartState = locStateMachine.states[nterm]
    for _, rule in ipairs(ntermRules) do
        if (type(rule[1]) == "table") then
            local locNterm = rule[1][1]
            local locState
            if not locStateMachine.states[locNterm] then
                locState = {
                    name = locNterm,
                    next = {}
                }
                locStateMachine.states[locNterm] = locState
                makeStateMachineRecStep(locStateMachine, locNterm, rules)
            else
               locState = locStateMachine.states[locNterm] 
            end

            table.insert(locStartState.next, {
                state = locState,
                rule = {{rule[2][1]}}
            })
        else
            table.insert(locStartState.next, {
                state = locStateMachine.finalState,
                rule = {rule[1]}
            })
        end
    end
end

function makeStateMachinesFromGrammar(rules)
    -- названия состояний совпадают с нетерминалами (кроме конечного состояния,
    -- у него новое название)
    local finalStateName = makeNewNterm(rules)
    local stateMachines = {}

    for nterm, ntermRules in pairs(rules) do
        stateMachines[nterm] = {}
        local locStateMachine = stateMachines[nterm]

        locStateMachine.startState = {
            name = nterm,
            next = {}
        }
        locStateMachine.finalState = {
            name = finalStateName,
            next = {}
        }
        locStateMachine.states = {}
        locStateMachine.states[nterm] = locStateMachine.startState
        locStateMachine.states[finalStateName] = locStateMachine.finalState

        makeStateMachineRecStep(locStateMachine, nterm, rules)
    end

    return stateMachines
end

function ntermIsOnRightSide(rules, nterm)
    for _, ntermRules in pairs(rules) do
        for _, rule in ipairs(ntermRules) do
            for _, smth in ipairs(rule) do
                if (type(smth) == "table") and (smth[1] == nterm) then
                    return true
                end
            end
        end
    end
    return false
end

function makeNewStartNtermIfNeeded(rules, startNterm)
    if ntermIsOnRightSide(rules, startNterm) then
        local newStartNterm = makeNewNterm(rules)
        rules[newStartNterm] = {{{startNterm}}}
        return newStartNterm
    else
        return startNterm
    end
end

function eliminNonsolitaryTerms(rules)
    local nterms = {}
    for nterm, _ in pairs(rules) do
        table.insert(nterms, nterm) 
    end
    for _, nterm in ipairs(nterms) do
        local ntermRules = rules[nterm]
        for _, rule in ipairs(ntermRules) do
            if not ((#rule == 1) and (type(rule[1]) == "string")) then
                for i, smth in ipairs(rule) do
                    if type(smth) == "string" then
                        local termNterm = "N_"..smth
                        if not rules[termNterm] then
                            rules[termNterm] = {}
                            table.insert(rules[termNterm], {
                                smth
                            })
                        end
                        rule[i] = {termNterm}
                    end
                end
            end
        end
    end
end

function findNtermByRules(rules, ntermRules)
    for nterm, ntermRulesI in pairs(rules) do
        if #ntermRules == #ntermRulesI then
            for _, rule in ipairs(ntermRules) do
                if not hasRuleIn(ntermRulesI, rule) then
                    goto continue
                end
            end
            return nterm
        end
        ::continue::
    end
end

function eliminMoreThan2Nonterms(rules)
    for nterm, ntermRules in pairs(rules) do
        for _, rule in ipairs(ntermRules) do
            local ruleLen = #rule
            -- можно было бы оптимизировать число нетерминалов, если не слева
            -- направо сворачивать, как я делаю, а как-то по-другому (опираясь
            -- на наибольшее число срабатываний findNtermByRules)
            for i = ruleLen, 3, -1 do
                local newNterm = findNtermByRules(rules, {{rule[i-1], rule[i]}})
                if not newNterm then
                    newNterm = makeNewNterm(rules)
                    rules[newNterm] = {{rule[i-1], rule[i]}}
                end
                table.remove(rule, i)
                rule[i-1] = {newNterm}
            end
        end
    end
end

function ntermWasPreviously(nterm, prevNterms)
    for _, ntermI in ipairs(prevNterms) do
        if nterm == ntermI then
            return true
        end
    end
    return false
end

function checkIfNullableNterm(nterm, nullableNterms, nonNullableNterms, rules, prevNterms)
    -- prevNterms нужно, чтобы не улететь в бесконечную рекурсию
    local ntermRules = rules[nterm]
    for i, rule in ipairs(ntermRules) do
        if #rule == 0 then
            table.remove(ntermRules, i) -- можно сразу тут убирать явные эпсилон правила
        else
            for _, smth in ipairs(rule) do
                if type(smth) ~= "table" then
                    goto continue
                end
                local locNterm = smth[1]
                if nonNullableNterms[locNterm] then
                    goto continue
                end
                if not nullableNterms[locNterm] then
                    if ntermWasPreviously(locNterm, prevNterms) then
                        goto continue -- сделано, чтобы не зациклиться в рекурсии
                    end
                    table.insert(prevNterms, locNterm)
                    checkIfNullableNterm(locNterm, nullableNterms, nonNullableNterms, 
                                         rules, prevNterms)
                end
                if not nullableNterms[locNterm] then
                    goto continue
                end
            end
        end
        nullableNterms[nterm] = true
        goto ret
        ::continue::
    end
    nonNullableNterms[nterm] = true
    ::ret::
end

function eliminEpsRules(rules)
    local nullableNterms, nonNullableNterms = {}, {}
    for nterm, ntermRules in pairs(rules) do
        local ntermRulesNum = #ntermRules
        local i = 1
        while i <= ntermRulesNum do
            local rule = ntermRules[i]
            if #rule == 0 then
                table.remove(ntermRules, i)
                nullableNterms[nterm] = true
            end
            for j, smth in ipairs(rule) do
                if type(smth) == "table" then
                    local locNterm = smth[1]
                    if not nonNullableNterms[locNterm] then
                        if not nullableNterms[locNterm] then
                            checkIfNullableNterm(locNterm, nullableNterms,
                                                 nonNullableNterms, rules, {nterm})
                        end
                        if nullableNterms[locNterm] then
                            local newRule = copy(rule)
                            table.remove(newRule, j)
                            if not hasRuleIn(ntermRules, newRule) then
                                table.insert(ntermRules,  newRule)
                                ntermRulesNum = ntermRulesNum + 1
                            end
                        end
                    end
                end
            end
            i = i + 1
        end
    end
end

function eliminUnitRuleStep(rules, nterm, checkedNterms, prevNterms)
    table.insert(prevNterms, nterm)
    local ntermRules = rules[nterm]
    local rulesNum = #ntermRules
    local i = 1
    while i <= rulesNum do
        local rule = ntermRules[i]
        if (#rule == 1) and (type(rule[1]) == "table") then
            local locNterm = rule[1][1]
            if (not checkedNterms[locNterm]) and (not ntermWasPreviously(locNterm, prevNterms)) then
                local newPrevNterms = copy(prevNterms) -- надо создать копию, тк иначе ветки рекурсии смешаются
                eliminUnitRuleStep(rules, locNterm, checkedNterms, newPrevNterms) -- чтобы не отлететь в
                                                                                  -- рекурсивную цепочку потом
            end
            table.remove(ntermRules, i)
            rulesNum = rulesNum - 1
            local locNtermRules = rules[locNterm]
            for _, locRule in ipairs(locNtermRules) do
                if not hasRuleIn(ntermRules, locRule) then -- кстати это не только избавляет от повторов,
                                                           -- но и от простой рекурсии типа N -> N (рекурсия
                                                           -- выбирается из рекурсии внутри рекурсии с
                                                           -- помощью prevNterms и table.remove(ntermRules, i))
                    table.insert(ntermRules, copy(locRule))
                    rulesNum = rulesNum + 1
                end
            end
        else
            i = i + 1
        end
    end
    table.insert(checkedNterms, nterm) 
end

function eliminUnitRules(rules)
    local checkedNterms = {}
    for nterm, ntermRules in pairs(rules) do
        if not checkedNterms[nterm] then
            eliminUnitRuleStep(rules, nterm, checkedNterms, {})
        end
    end
end

function makeCNF(rules, startNterm) 
    local startNterm = makeNewStartNtermIfNeeded(rules, startNterm)
    eliminNonsolitaryTerms(rules)
    eliminMoreThan2Nonterms(rules)
    eliminEpsRules(rules)
    eliminUnitRules(rules)
    return startNterm
end

function blumKochAlgorithm(rules, startNterm)
    io.write("--- 2nd algorithm: ---\n")
    local stateMachines = makeStateMachinesFromGrammar(rules) -- хоть и названия состояний у автоматов совпадают, но
                                                              -- сами состояния разные, тк автоматы разные
    reverseStateMachines(stateMachines)
    outputStateMachines(stateMachines)
    local grammars = makeGrammarsFromStateMachines(stateMachines) -- аналогично, нетерминалы в разных грамматиках называются
                                                                  -- одинаково только ради удобства, на деле они разные
    local newStartNterm1Part = stateMachines[startNterm].startState.name
    local newStartNterm = newStartNterm1Part.."_"..startNterm
    local GNFGrammar = makeFinalGrammar(grammars, newStartNterm1Part)
    removeUnreachableNterms(GNFGrammar, newStartNterm) -- могут остаться лишние нетерминалы
    outputRules(GNFGrammar, newStartNterm)
end

function concatRules(ruleLeft, ruleRight)
    local rule = {}
    local i = 1
    for _, val in ipairs(ruleLeft) do
        rule[i] = val
        i = i + 1
    end
    for _, val in ipairs(ruleRight) do
        rule[i] = val
        i = i + 1
    end
    return rule
end

function findNtermByOrder(i, ntermsLexOrd)
    for nterm, ord in pairs(ntermsLexOrd) do
        if (ord == i) then
            return nterm
        end
    end
end

function makeNewNterm(rules)
    -- ууу, рандом
    local newNterm
    while true do
        newNterm = ""
        for i = 1, math.random(1, 5) do
            newNterm = newNterm .. string.char(math.random(65, 90))
        end
        if not rules[newNterm] then
            break
        end
    end
    return newNterm
end

function findNumElemsInTbl(tbl)
    local count = 0
    for _ in pairs(tbl) do
        count = count + 1
    end
    return count
end

function ruleIsLeftRec(rule, nterm) 
    return type(rule[1]) == "table" and rule[1][1] == nterm
end

function useNtermsLexOrd(rules, ntermsLexOrd)
    local ntermsNum = findNumElemsInTbl(rules)
    local newNtermCounter = 0
    for i = 1, ntermsNum, 1 do
        local nterm = findNtermByOrder(i, ntermsLexOrd)
        local ntermRules = rules[nterm]

        local j = 1
        local ntermRulesNum = #ntermRules
        local leftRecRules = {}
        while (j <= ntermRulesNum) do
            local rule = ntermRules[j]
            if (type(rule[1]) == "table") then
                local locNterm = rule[1][1]
                if (ntermsLexOrd[nterm] > ntermsLexOrd[locNterm]) then
                    table.remove(ntermRules, j)
                    table.remove(rule, 1)
                    for _, locRule in ipairs(rules[locNterm]) do
                        local newRule = concatRules(locRule, rule)
                        --addRule(ntermRules, newRule) -- походу нет смысла проверять на повторное вхождение
                        table.insert(ntermRules, newRule)
                    end
                    ntermRulesNum = ntermRulesNum - 1 + #rules[locNterm]                   
                else
                    if (ntermsLexOrd[nterm] == ntermsLexOrd[locNterm]) then
                        --addRule(leftRecRules, copy(rule)) -- походу нет смысла проверять на повторное вхождение
                        table.insert(leftRecRules, copy(rule))
                    end
                    j = j + 1
                end
            else
                j = j + 1
            end
        end

        if (#leftRecRules ~= 0) then
            local newNterm = makeNewNterm(rules)
            newNtermCounter = newNtermCounter + 1
            ntermsLexOrd[newNterm] = -newNtermCounter + 1
            rules[newNterm] = {}
            local i = 1
            local prevNtermRulesCount = #ntermRules
            while (i <= prevNtermRulesCount) do
                if ruleIsLeftRec(ntermRules[i], nterm) then
                    table.remove(ntermRules, i)
                    prevNtermRulesCount = prevNtermRulesCount - 1 
                else
                    table.insert(ntermRules, concatRules(ntermRules[i], {{newNterm}}))
                    for _, leftRecRule in ipairs(leftRecRules) do
                        table.insert(rules[newNterm], copy(leftRecRule))
                        table.insert(rules[newNterm], concatRules(leftRecRule, {{newNterm}}))
                    end 
                    i = i + 1
                end
            end
        end
    end

    for nterm, _ in pairs(ntermsLexOrd) do
        ntermsLexOrd[nterm] = ntermsLexOrd[nterm] + newNtermCounter
    end
end

function outputNtermsLexOrd(ntermsLexOrd)
    io.write("--- Partial order of non-terminals: ---\n")
    for term, i in pairs(ntermsLexOrd) do
        io.write(term..": "..i.."\n")
    end
    io.write("\n")
end

function makeNtermsLexOrd(nterm, rules, ntermsLexOrd, counter)
    ntermsLexOrd[nterm] = counter[1]
    counter[1] = counter[1] + 1 -- counter должен быть числом, но тк только таблицы
    -- передаются по ссылке, то пришлось упаковать его в таблицу (костыль типа)
    for _, rule in ipairs(rules[nterm]) do
        for _, smth in ipairs(rule) do
            if (type(smth) == "table") then
                local LocNterm = smth[1]
                if (not ntermsLexOrd[LocNterm]) then
                    makeNtermsLexOrd(LocNterm, rules, ntermsLexOrd, counter)
                end
            end
        end
    end
end

function leftRuleSweep(rules)
    for nterm, ntermRules in pairs(rules) do
        local i = 1
        local ntermRulesNum = #ntermRules
        while (i <= ntermRulesNum) do
            local rule = ntermRules[i]
            if (type(rule[1]) == "table") then
                local locNterm = rule[1][1]
                table.remove(ntermRules, i)
                table.remove(rule, 1)
                ntermRulesNum = ntermRulesNum - 1
                for _, locRule in ipairs(rules[locNterm]) do
                    local newRule = concatRules(locRule, rule)
                    if not hasRuleIn(ntermRules, newRule) then
                        --addRule(ntermRules, newRule)  -- походу нет смысла проверять на повторное вхождение
                        table.insert(ntermRules, newRule)
                        ntermRulesNum = ntermRulesNum + 1
                    end
                end
            else
                i = i + 1
            end
        end
    end
end

function leftRecAlgorithm(rules, startNterm)
    io.write("--- 1st algorithm: ---\n")
    local ntermsLexOrd = {}
    makeNtermsLexOrd(startNterm, rules, ntermsLexOrd, {1})
    useNtermsLexOrd(rules, ntermsLexOrd)
    leftRuleSweep(rules)
    removeUnreachableNterms(rules, startNterm) -- могут остаться лишние нетерминалы
    outputNtermsLexOrd(ntermsLexOrd)
    outputRules(rules, startNterm)
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

function inputRules()
    local rules = {}
    for line in io.lines() do
        local first, last = 0, 0
        first, last = line:find("%[%a+%d*%]", 0)
        local startNterm = line:sub(first + 1, last - 1)
        if not rules[startNterm] then
           rules[startNterm] = {} 
        end
        local rule = {}

        first, last = line:find("->", last + 1)
        while true do
            first, last = line:find("[%[|%a|%d]", last + 1)
            if not first then break end
            local term = line:sub(first, last)
            if term == "[" then
                first, last = line:find("%a+%d*%]", first + 1)
                local nterm = line:sub(first, last - 1)
                table.insert(rule, {nterm})
            else
                table.insert(rule, term)
            end
        end
        table.insert(rules[startNterm], rule)
    end
    return rules
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

function goThroughReachableNterms(rules, nterm, unreachableNterms)
    unreachableNterms[nterm] = nil
    local ntermRules = rules[nterm]
    for _, rule in ipairs(ntermRules) do
        for _, smth in ipairs(rule) do
            if type(smth) == "table" then
                local locNterm = smth[1]
                if unreachableNterms[locNterm] then
                    goThroughReachableNterms(rules, locNterm, unreachableNterms)
                end
            end
        end
    end
end

function removeUnreachableNterms(rules, startNterm)
    local unreachableNterms = {}
    for nterm, _ in pairs(rules) do
        unreachableNterms[nterm] = true
    end
    goThroughReachableNterms(rules, startNterm, unreachableNterms)
    for nterm, _ in pairs(unreachableNterms) do
        rules[nterm] = nil
    end
end

function main()
    local rules = inputRules()
    local startNterm = makeCNF(rules, "S") -- require не робит, так что в main.lua сделано
    removeUnreachableNterms(rules, startNterm) -- после привидения к хнф могут появиться
    local rulesCopy = copy(rules)
    leftRecAlgorithm(rules, startNterm)
    blumKochAlgorithm(rulesCopy, startNterm)
end

main()