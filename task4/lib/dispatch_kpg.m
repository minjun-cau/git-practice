function c = dispatch_kpg(c, load_scale, loss_rate)
% DISPATCH_KPG  부하 수준 변경 + 급전순위(merit order)에 따른 발전기 출력 재배분
%   load_scale : 일반 부하(Pd>0) 배율   (재생E 모선 Pd<0 은 그대로 둠)
%   loss_rate  : 송전손실 추정 비율 (부족분은 Slack 이 담당)
%
%   급전순위 : 원자력(기저) → 석탄 → LNG
%     1) 기동 중인 발전기를 모두 최소출력(Pmin)으로 놓고
%     2) 남은 수요를 원자력 → 석탄 → LNG 순으로 Pmax 까지 채움
%     3) 그래도 부족하면 정지 발전기(LNG)를 추가 기동
%     4) 최소출력 합이 수요보다 크면 LNG 부터 정지
    if nargin < 3, loss_rate = 0.01; end
    pos = c.Pd > 0;
    c.Pd(pos) = c.Pd(pos) * load_scale;
    c.Qd(pos) = c.Qd(pos) * load_scale;
    D = sum(c.Pd) * (1 + loss_rate);

    order = {'Nuclear', 'Coal', 'LNG'};
    rank = zeros(numel(c.Pg), 1);
    for k = 1:3, rank(strcmp(c.fuel, order{k})) = k; end

    % 3) 부족하면 정지 발전기 기동 (LNG 우선, 큰 것부터)
    off = find(~c.gon);
    [~, ix] = sort(rank(off) * 1e6 - c.Pmax(off), 'descend');
    off = off(ix);
    k = 1;
    while sum(c.Pmax(c.gon)) < D && k <= numel(off)
        c.gon(off(k)) = true;  k = k + 1;
    end
    % 4) 최소출력 합이 수요보다 크면 LNG → 석탄 순으로 정지 (작은 것부터)
    while sum(c.Pmin(c.gon)) > D
        mr = false(size(c.gon));
        if isfield(c, 'mustrun'), mr = c.mustrun; end
        cand = find(c.gon & rank >= 2 & ~mr);
        if isempty(cand), break; end           % 더 정지할 발전기가 없음 (출력제어는 호출 측에서 처리)
        [~, ix] = sort(rank(cand) * 1e6 - c.Pmax(cand), 'descend');
        c.gon(cand(ix(1))) = false;
    end

    % 1), 2) 급전
    c.Pg(:) = 0;
    c.Pg(c.gon) = c.Pmin(c.gon);
    remain = D - sum(c.Pg);
    for r = 1:3
        idx = find(c.gon & rank == r);
        head = c.Pmax(idx) - c.Pg(idx);
        if sum(head) <= remain
            c.Pg(idx) = c.Pmax(idx);  remain = remain - sum(head);
        else
            c.Pg(idx) = c.Pg(idx) + head * remain / sum(head);   % 같은 연료끼리는 비례 배분
            remain = 0;
        end
    end
    if remain > 1, warning('발전 용량 부족: %.0f MW', remain); end
end
