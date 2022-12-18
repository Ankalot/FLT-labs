function findFollow(rules, nterm, visitedNterms)
    -- тут я не указываю $ в follow, тк сложно и по идее не нужно
    local follow = {}

    for locNterm, ntermRules in pairs(rules) do
        for _, rule in ipairs(ntermRules) do
            for i, smth in ipairs(rule) do
                if type(smth) == "table" and smth[1] == nterm then
                    local j = i + 1
                    local numRules = #rule
                    while j <= numRules do
                        local nextSmth = rule[j]
                        if type(nextSmth) == "string" then
                            follow[nextSmth] = true
                            break
                        else
                            local nextNterm = nextSmth[1]
                            local nextNtermFirst = {}
                            for _, nextNtermRule in ipairs(rules[nextNterm]) do
                                local locVisitedNterms = {}
                                locVisitedNterms[nextNtermFirst] = true
                                addTblsToTbl(nextNtermFirst, findFirst(rules, nextNtermRule, locVisitedNterms))
                            end

                            if nextNtermFirst.eps_ then
                                nextNtermFirst.eps_ = nil
                                addTblsToTbl(follow, nextNtermFirst)
                            else
                                addTblsToTbl(follow, nextNtermFirst)
                                break
                            end
                        end
                        j = j + 1
                    end
                    if j == numRules + 1 then
                        if not visitedNterms[locNterm] then
                            visitedNterms[locNterm] = true
                            addTblsToTbl(follow, findFollow(rules, locNterm, visitedNterms))
                        end
                    end
                end
            end
        end
    end

    return follow
end

function addTblsToTbl(tbl1, tbl2)
    for key2, val2 in pairs(tbl2) do
        tbl1[key2] = val2
    end
end

function tablesHaveIntersection(tbl1, tbl2)
    for key1, val1 in pairs(tbl1) do
        if tbl2[key1] == val1 then
            return true
        end
    end
    return false
end

function isEpsilonNterm(rules, nterm, visitedNterms)
    if not visitedNterms then
        visitedNterms = {}
    end
    visitedNterms[nterm] = true
    for _, rule in ipairs(rules[nterm]) do
        for _, smth in ipairs(rule) do
            if type(smth) == "string" then
                return false
            end
            local locNterm = smth[1]
            if not visitedNterms[locNterm] then
                if not isEpsilonNterm(rules, locNterm, visitedNterms) then
                    return false
                end
            end
        end
    end
    return true
end

function findFirst(rules, rule, visitedNterms)
    local first = {}
    local wasNotEpsNterm = false

    for i = 1, #rule do
        local smth = rule[i]
        if type(smth) == "string" then
            wasNotEpsNterm = true
            first[smth] = true
            break
        else
            local nterm = smth[1]
            local wasEps = false
            if not isEpsilonNterm(rules, nterm) then
                wasNotEpsNterm = true
                if not visitedNterms[nterm] then
                    visitedNterms[nterm] = true
                    for _, ntermRule in ipairs(rules[nterm]) do
                        local ntermRuleFirst = findFirst(rules, ntermRule, visitedNterms)
                        if ntermRuleFirst.eps_ then
                            wasEps = true
                            ntermRuleFirst.eps_ = nil
                        end
                        addTblsToTbl(first, ntermRuleFirst)
                    end
                end
                if not wasEps then
                    break
                end
            end
        end
    end

    if (#first == 0) and (not wasNotEpsNterm) then
        first.eps_ = true
    end 
    return first
end

function grammarIsLL1(rules)
    -- скорее всего этот алгос неэффективный
    for nterm, ntermRules in pairs(rules) do
        local ntermFirst = {}
        local ntermFollow = {}
        for _, rule in ipairs(ntermRules) do
            local visitedNterms = {}
            visitedNterms[nterm] = true
            local first = findFirst(rules, rule, visitedNterms)
            --[[io.write(nterm.." FIRST: ") -- для отладки
            for firstTerm, _ in pairs(first) do
                io.write(firstTerm..", ")
            end
            io.write("\n")]]
            if first.eps_ then
                if #ntermFollow == 0 then
                    visitedNterms = {}
                    visitedNterms[nterm] = true
                    local follow = findFollow(rules, nterm, visitedNterms)
                    --[[io.write(nterm.." FOLLOW: ") -- для отладки
                    for followTerm, _ in pairs(follow) do
                        io.write(followTerm..", ")
                    end
                    io.write("\n")]]
                    if tablesHaveIntersection(ntermFirst, follow) then
                        return false
                    end
                    addTblsToTbl(ntermFollow, follow)
                end
                first.eps_ = nil
            end

            if tablesHaveIntersection(ntermFirst, first) or tablesHaveIntersection(ntermFollow, first) then
                return false
            end
            addTblsToTbl(ntermFirst, first)
        end
    end
    return true
end