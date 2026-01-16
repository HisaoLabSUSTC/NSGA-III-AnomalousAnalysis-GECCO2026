% phs = {@MinusWFG1,@MinusWFG2,@MinusWFG3,@MinusWFG4,@MinusWFG5,@MinusWFG6,@MinusWFG7,@MinusWFG8,@MinusWFG9,...
%     @VNT1, @VNT2, @VNT3,...
%     @WFG1,@WFG2,@WFG3,@WFG4,@WFG5,@WFG6,@WFG7,@WFG8,@WFG9,@ZDT1,@ZDT2,@ZDT3,@ZDT4,@ZDT6, ...
%     @BT1, @BT2, @BT3, @BT4, @BT5, @BT6, @BT7, @BT8, @BT9, ...
%     @DTLZ1, @DTLZ2, @DTLZ3, @DTLZ4, @DTLZ5, @DTLZ6, @DTLZ7, @IDTLZ1, @IDTLZ2, ...
%     @SDTLZ1, @SDTLZ2, @IMOP1, @IMOP2, @IMOP3, @IMOP4, @IMOP5, @IMOP6, @IMOP7, @IMOP8, ...
%     @MaF1,@MaF2,@MaF3,@MaF4,@MaF5,@MaF13,@MaF14,@MaF15,...
%     @RWA1,@RWA2,@RWA3,@RWA4,@RWA5,@RWA6,@RWA7,...
%     @UF1,@UF2,@UF3,@UF4,@UF5,@UF6,@UF7,@UF8,@UF9,@UF10,...
%     @MinusDTLZ1,@MinusDTLZ2,@MinusDTLZ3,@MinusDTLZ4,@MinusDTLZ5,@MinusDTLZ6};
% phs = {@DTLZ1, @DTLZ2, @IDTLZ1, @IDTLZ2, @WFG1, @WFG2, @MaF8, @MaF9};
phs = {@DTLZ1, @DTLZ2, @IDTLZ1, @IDTLZ2, @WFG1, @WFG2, @RWA9};
pns = cellfun(@func2str, phs, 'UniformOutput', false);

reverseStr = ''; % Initialize as empty
fprintf('Progress: '); % The static part of the message
total = 85;

prob2rhv = containers.Map();
for i=1:numel(pns)
    msg = sprintf('%d/%d', i, total); 
    fprintf([reverseStr, msg]);
    reverseStr = repmat('\b', 1, length(msg));
    ph = phs{i};
    pn = func2str(ph);
    Problem = ph('M', 5);
    [PF, ref] = GetPFnRef(Problem);
    % [~, PF] = getLeastCrowdedPoints(PF, 126);
    hv = stk_dominatedhv(PF, ref);
    prob2rhv(pn) = hv;
end

mkdir('./Info/FinalHV/ReferenceHV')
save('./Info/FinalHV/ReferenceHV/prob2rhv.mat', 'prob2rhv')