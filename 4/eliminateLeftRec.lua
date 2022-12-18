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

function eliminateLeftRec(rules, startNterm)
    local ntermsLexOrd = {}
    makeNtermsLexOrd(startNterm, rules, ntermsLexOrd, {1})
    useNtermsLexOrd(rules, ntermsLexOrd)
    leftRuleSweep(rules)
    removeUnreachableNterms(rules, startNterm) -- могут остаться лишние нетерминалы
end