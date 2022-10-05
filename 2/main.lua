function isSynchronizing(transitions)
    local firstState = transitions[1]
    if firstState == "none" then
        return nil
    end
    for _, state in ipairs(transitions) do
        if state ~= firstState then
            return nil
        end
    end
    return firstState
end

function outputEqClassesAdditionalInfo(eqClasses, initState)
    io.write("=====\nAdditional info about equivalence classes:\n")
    for word, transitions in pairs(eqClasses) do
        io.write("\'"..word.."\':\n")
        io.write("  Equivalence classes v, that vw is in language:\n")
        for word1, _ in pairs(eqClasses) do
            if isInLanguage(word1..word, initState) then
                io.write("    \'"..word1.."\'\n")
            end
        end
        io.write("  Equivalence classes u, that wu is in language:\n")
        for word1, _ in pairs(eqClasses) do
            if isInLanguage(word..word1, initState) then
                io.write("    \'"..word1.."\'\n")
            end
        end
        io.write("  Pairs of equivalence classes v, u that vwu is in language:\n")
        for word1, _ in pairs(eqClasses) do
            for word2, _ in pairs(eqClasses) do
                if isInLanguage(word1..word..word2, initState) then
                    io.write("    \'"..word1.."\', \'"..word2.."\'\n")
                end
            end
        end
        local synchState = isSynchronizing(transitions)
        if synchState then
            io.write("  The state to which word synchronizes: "..synchState.name.."\n")
        else
            io.write("  This word doesn't synchronize\n")
        end
    end
end

function isInLanguage(word, initState)
    local state = initState
    for i = 1, #word do
        state = state.next[word:sub(i, i)]
        if not state then
            return false
        end
    end
    return state.isFinal
end

function outputEqClassesInLang(eqClasses, initState)
    io.write("=====\nEquivalence classes belonging to the language:\n")
    for word, _ in pairs(eqClasses) do
        if isInLanguage(word, initState) then
            io.write("\'"..word.."\'\n")
        end
    end
end

function outputEqClassesAndRules(eqClasses, rules)
    local allStates = eqClasses[""]
    local statesNum = #allStates
    io.write("Equivalence classes:\n")
    for word, transitions in pairs(eqClasses) do
        io.write("\'"..word.."\':\n")
        for i = 1, statesNum do
            local state = transitions[i]
            io.write("  "..allStates[i].name.." -> "..
                     (state == "none" and "none" or state.name).."\n")
        end
    end
    io.write("=====\nRules:\n")
    for from, to in pairs(rules) do
        io.write("\'"..from.."\' -> \'"..to.."\'\n")
    end
end

function canRewrite(word, rules)
    for from, _ in pairs(rules) do
        if word:find(from) then
            return true
        end
    end
    return false
end

function addLetterToWords(words, letters)
    local newWords = { }
    for _, letter in ipairs(letters) do
        for _, word in ipairs(words) do
            table.insert(newWords, letter..word)
        end
    end
    return newWords
end

function findTransitions(states, letter)
    local transitions = { }
    for _, state in pairs(states) do
        if state == "none" then
            table.insert(transitions, "none")
        else
            local nextState = state.next[letter]
            if nextState then
                table.insert(transitions, state.next[letter])
            else
                table.insert(transitions, "none")
            end
        end
    end
    return transitions
end

function groupStates(initState, finalStates, intermediateStates)
    local allStates = { }
    if not finalStates[initState.name] then
        table.insert(allStates, initState)
    end
    for stateName, state in pairs(finalStates) do
        table.insert(allStates, state)
    end
    for stateName, state in pairs(intermediateStates) do
        table.insert(allStates, state)
    end
    return allStates
end

function algorithm(initState, finalStates, intermediateStates, letters)
    local transitionsMeta = {
        __eq = function (tbl1, tbl2)
            if length(tbl1) ~= length(tbl2) then
                return false
            end
            for i, state in ipairs(tbl1) do
                if state == "none" then
                    if tbl2[i] ~= "none" then
                        return false
                    end
                else
                    if tbl2[i] == "none" or tbl2[i].name ~= state.name then
                        return false
                    end
                end
            end
            return true
        end
    }
    table.sort(letters)
    local words = {""}
    local monoidChanged = true
    local rules, eqClasses = { }, { }
    local allStates = groupStates(initState, finalStates, intermediateStates)
    setmetatable(allStates, transitionsMeta)
    eqClasses[""] = allStates
    while monoidChanged do
        monoidChanged = false
        words = addLetterToWords(words, letters)
        for _, word in ipairs(words) do
            if not canRewrite(word, rules) then
                local transitions = findTransitions(eqClasses[word:sub(1, #word - 1)],
                                                    word:sub(#word, #word))
                setmetatable(transitions, transitionsMeta)
                local eqWord = isInTable(eqClasses, transitions)
                if eqWord then
                    rules[word] = eqWord
                else
                    eqClasses[word] = transitions
                end
                monoidChanged = true
            end
        end
    end
    return eqClasses, rules
end

function isUnreachableIterate(initState, state, prevStates)
    if state == initState then
        return false
    end
    prevStates[state.name] = state
    for _, prev in ipairs(state.prev) do
        local prevState = prev.state
        if not prevStates[prevState.name] and 
           not isUnreachableIterate(initState, prevState, prevStates) then
            return false
        end
    end
    return true
end

function isUnreachable(initState, state)
    local prevStates = { }
    prevStates[state.name] = state
    for _, prev in ipairs(state.prev) do
        local prevState = prev.state
        if not prevStates[prevState.name] and
           not isUnreachableIterate(initState, prevState, prevStates) then
            return false, nil
        end
    end
    return true, prevStates
end

function removeUnreachable(initState, intermediateStates, finalStates)
    for _, state in pairs(finalStates) do
        if state ~= initState then
            local isUnreachableBool, prevStates = isUnreachable(initState, state)
            if isUnreachableBool then
                for name, stateToRemove in pairs(prevStates) do
                    for _, prev in ipairs(stateToRemove.prev) do
                        prev.state.next[prev.letter] = nil
                    end
                    if intermediateStates[name] then
                        intermediateStates[name] = nil
                    else
                        finalStates[name] = nil
                    end
                end
            end
        end
    end
end

function length(tbl)
    local len = 0
    for _ in pairs(tbl) do
        len = len + 1
    end
    return len
end

function isTrapIterate(state, reachableStates)
    if state.isFinal then
        return false
    end
    reachableStates[state.name] = state
    for _, nextState in pairs(state.next) do
        if not reachableStates[nextState.name] and 
           not isTrapIterate(nextState, reachableStates) then
            return false
        end
    end
    return true
end

function isTrap(state)
    local reachableStates = { }
    reachableStates[state.name] = state
    for _, nextState in pairs(state.next) do
        if not reachableStates[nextState.name] and
           not isTrapIterate(nextState, reachableStates) then
            return false, nil
        end
    end
    return true, reachableStates
end

function removeTraps(intermediateStates)
    for _, state in pairs(intermediateStates) do
        local isTrapBool, reachableStates = isTrap(state)
        if isTrapBool then
            for name, stateToRemove in pairs(reachableStates) do
                for _, prev in ipairs(stateToRemove.prev) do
                    prev.state.next[prev.letter] = nil
                end
                intermediateStates[name] = nil
            end
        end
    end
end

function findState(stateName, initState, finalStates, intermediateStates)
    local state
    if initState.name == stateName then
        state = initState
    elseif finalStates[stateName] then
        state = finalStates[stateName]
    elseif intermediateStates[stateName] then
        state = intermediateStates[stateName]
    else
        state = {
            isFinal = false,
            name = stateName,
            prev = { },
            next = { }
        }
        intermediateStates[stateName] = state
    end
    return state
end

function isInTable(tbl, obj) 
    for key, val in pairs(tbl) do
        if val == obj then
            return key
        end
    end
    return nil
end

function addTransition(str, initState, finalStates, intermediateStates, letters)
    local end1 = str:sub(3,3) == "," and 2 or 3
    local state1Name = str:sub(2, end1)
    local state1 = findState(state1Name, initState, finalStates, intermediateStates)

    end1 = end1 + 2
    local letter = str:sub(end1, end1)
    if not isInTable(letters, letter) then
        table.insert(letters, letter)
    end

    end1 = end1 + 4
    local state2Name = str:sub(end1, str:len())
    local state2 = findState(state2Name, initState, finalStates, intermediateStates)

    if state1.next[letter] then
        io.write("Автомат не детерменированный\n")
        os.exit()
    end
    state1.next[letter] = state2
    table.insert(state2.prev, {
        state = state1,
        letter = letter
    })
end

function inputStates(str)
    local initState, finalStates = {}, {}
    local first, last = 0, 0
    first, last = str:find("%a%d?", first+1)
    local initStateName = str:sub(first, last)
    initState = {
        isFinal = false,
        name = initStateName,
        prev = { },
        next = { }
    }
    local stateName
    while true do
        first, last = str:find("%a%d?", first+1)
        if not first then break end
        stateName = str:sub(first, last)
        if stateName == initStateName then
            initState.isFinal = true
            finalStates[stateName] = initState
        else
            finalStates[stateName] = {
                isFinal = true,
                name = stateName,
                prev = { },
                next = { }
            }
        end
    end
    return initState, finalStates
end

function input()
    local initAndFinalStatesStr = io.read()
    local initState, finalStates = inputStates(initAndFinalStatesStr)
    local intermediateStates, letters = {}, {}
    for line in io.lines() do
        addTransition(line, initState, finalStates, intermediateStates, letters)
    end
    return initState, finalStates, intermediateStates, letters
end

function main()
    local initState, finalStates, intermediateStates, letters = input()
    removeTraps(intermediateStates)
    removeUnreachable(initState, intermediateStates, finalStates)
    local eqClasses, rules = algorithm(initState, finalStates, intermediateStates, letters)
    outputEqClassesAndRules(eqClasses, rules)
    outputEqClassesInLang(eqClasses, initState)
    outputEqClassesAdditionalInfo(eqClasses, initState)
end

main()