function [P, R] = best_hvdc(cg, hvdc, steps)
% BEST_HVDC  HVDC 송전량 조합을 바꿔가며 과부하가 가장 적은 운전점 탐색
%   목적 : (1) 수렴  (2) 100 % 초과 선로 수 최소  (3) 최대 부하율 최소
%   steps : 각 링크 정격 대비 송전 비율 후보 (예: 0:0.25:1)
    nh = size(hvdc, 1);
    grids = cell(1, nh);
    [grids{:}] = ndgrid(steps);
    combos = zeros(numel(grids{1}), nh);
    for k = 1:nh, combos(:,k) = grids{k}(:); end
    best = [inf inf];  P = hvdc(:,3) * 0;  R = [];
    for i = 1:size(combos, 1)
        M = struct('hvdc', [hvdc(:,1:2) hvdc(:,3).*combos(i,:)' hvdc(:,4)], 'statcom', zeros(0,2));
        [~, ~, Ri] = solve_add(cg, M, []);
        if ~Ri.conv, continue; end
        score = [Ri.nover Ri.maxload];
        if score(1) < best(1) || (score(1) == best(1) && score(2) < best(2))
            best = score;  P = M.hvdc(:,3);  R = Ri;
        end
    end
end
