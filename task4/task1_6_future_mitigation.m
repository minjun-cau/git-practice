%% Task 1-6 : 대한민국 상세화 미래 계통 안정도 문제 해소방안
%   Task 1-5 문제점
%     - 미래 경부하 : 신안 해상풍력 5 GW 를 154 kV 에 연계하면 해 없음(전압붕괴) → 2.5 GW 출력제한 필요
%                    과부하 29개 선로(최대 186 %), 서남부 저전압(0.93 pu), 손실 3.7 %
%     - 미래 최대부하 : 수도권(서울·경기) 유입 선로 과부하 14개 (최대 129 %)
%   대책 (단계적으로 적용하며 효과 확인)
%     1단계 HVDC  : 서해안 HVDC (신안→시흥, 영암→서용인) + 동해안 HVDC (울진→가평)
%     2단계 선로증설 : 남은 과부하 선로를 병행 회선 추가로 보강 (가장 심한 선로부터 반복)
%     3단계 STATCOM  : 허용범위(0.95~1.05 pu)를 벗어난 모선에 무효전력 보상
clear; clc;
root = fileparts(mfilename('fullpath'));
addpath(fullfile(root, 'lib'));
dd = fullfile(root, 'data');  outdir = fullfile(root, 'results');
c0 = load_kpg(dd);

% 미래 시나리오 발전계획 (재생E 출력제한 없이 전량 수용하는 것이 목표)
cg.peak  = dispatch_kpg(future_kpg(c0, future_def('peak')),  1.0);
cg.light = dispatch_kpg(future_kpg(c0, future_def('light')), 1.0);
sc = {'peak', 'light'};
sc_kr = {'미래 최대부하', '미래 경부하'};

% HVDC 송전량은 시나리오별로 운영 (재생E 출력에 맞춰 조정) [MW]
%            송전   수전   peak   light  (손실 3 %)
hv_def = [   89    166   2000   4500;    % 서해안 HVDC ① 신안 해상풍력 → 시흥 (수도권 서부 데이터센터)
             92     23   2000   4000;    % 서해안 HVDC ② 영암 → 서용인 (반도체 클러스터)
             72     35   4000   4000];   % 동해안 HVDC   울진 → 가평 (동해안 원전 → 수도권 동부)
hv_name = {'서해안① 신안→시흥', '서해안② 영암→서용인', '동해안 울진→가평'};

steplog = {};   % 단계별 결과 기록
M0 = struct('hvdc', zeros(0,4), 'dup', [], 'statcom', zeros(0,2));

%% 0단계 : 대책 없음 (재생E 전량)
for s = 1:2
    [~, ~, S] = solve_future(cg.(sc{s}), M0);
    steplog(end+1,:) = {'0 대책 없음', sc_kr{s}, S}; %#ok<SAGROW>
end

%% 1단계 : HVDC
M = M0;
for s = 1:2
    Ms = M;  Ms.hvdc = [hv_def(:,1:2) hv_def(:,2+s) 0.03*ones(3,1)];
    [~, ~, S] = solve_future(cg.(sc{s}), Ms);
    steplog(end+1,:) = {'1 HVDC', sc_kr{s}, S}; %#ok<SAGROW>
end

%% 2단계 : 과부하 선로 증설 (두 시나리오 모두 100 % 이하가 될 때까지)
%   데이터의 선로 한 행은 n회선 묶음 → 1회선 추가 = r,x ×n/(n+1), b·정격 ×(n+1)/n (lib/add_circuits.m)
%   매 반복마다 각 시나리오에서 부하율이 가장 높은 선로에 1회선씩 추가 (lib/greedy_reinforce.m)
Mh = cell(1, 2);
for s = 1:2
    Mh{s} = struct('hvdc', [hv_def(:,1:2) hv_def(:,2+s) 0.03*ones(3,1)], 'statcom', zeros(0,2));
end
add = greedy_reinforce({cg.peak, cg.light}, Mh, numel(c0.f));
for s = 1:2
    [~, ~, S] = solve_add(cg.(sc{s}), Mh{s}, add);
    steplog(end+1,:) = {'2 HVDC+선로증설', sc_kr{s}, S}; %#ok<SAGROW>
end

%% 3단계 : STATCOM (전압 위반 모선)
stat = zeros(0, 2);
for it = 1:10
    added = false;
    for s = 1:2
        Ms = Mh{s};  Ms.statcom = stat;
        [~, ~, S] = solve_add(cg.(sc{s}), Ms, add);
        [vmn, vmx] = vlim(c0.kv);
        bad = find(S.V < vmn | S.V > vmx);
        bad = setdiff(bad, stat(:,1));
        if ~isempty(bad)
            stat = [stat; bad(:) ones(numel(bad),1)]; %#ok<AGROW>
            added = true;
        end
    end
    if ~added, break; end
end
for s = 1:2, Mh{s}.statcom = stat; end
M.add = add;  M.statcom = stat;

%% 최종 결과
fprintf('=== Task 1-6 : 미래 계통 보강 대책 ===\n');
for k = 1:size(hv_def, 1)
    fprintf('HVDC %-22s : 최대부하 %.1f GW / 경부하 %.1f GW\n', hv_name{k}, hv_def(k,3)/1000, hv_def(k,4)/1000);
end
fprintf('선로 증설 %d회선 (선로 %d곳) :\n', sum(add), nnz(add));
list_add(c0, add);
if isempty(stat)
    fprintf('STATCOM : 필요 없음 (HVDC 변환소(VSC)의 전압제어로 모든 모선 허용범위 유지)\n');
else
    fprintf('STATCOM %d개소 : %s\n', size(stat,1), strjoin(c0.name_kr(stat(:,1))', ', '));
end

final = struct();
for s = 1:2
    [res, cc, S] = solve_add(cg.(sc{s}), Mh{s}, add);
    if ~isempty(stat)   % STATCOM 이 필요했던 경우에만 별도 단계로 기록
        steplog(end+1,:) = {'3 HVDC+증설+STATCOM', sc_kr{s}, S}; %#ok<SAGROW>
    end
    Sf = summarize_kpg(cc, res, ['Task 1-6: ' sc_kr{s} ' 대책 후'], outdir, ['task1_6_final_' sc{s}]);
    Qst = res.Q(cc.extra_pv) * cc.baseMVA + cc.Qd(cc.extra_pv);   % 전압제어 설비 무효전력
    fprintf('  HVDC 변환소·STATCOM 무효전력 (음수 = 흡수):\n');
    for j = 1:numel(cc.extra_pv)
        fprintf('     %-8s %8.0f MVar\n', cc.name_kr{cc.extra_pv(j)}, Qst(j));
    end
    final.(sc{s}) = struct('res', res, 'c', cc, 'S', Sf);
end

%% 단계별 비교표 / 그림
fprintf('\n===== 단계별 효과 =====\n');
fprintf('%-22s %-12s 수렴  Vmin   Vmax  최대부하율 과부하선로 손실[MW]\n', '대책', '시나리오');
T = zeros(size(steplog,1), 5);
for k = 1:size(steplog, 1)
    S = steplog{k,3};
    if S.conv
        T(k,:) = [min(S.V) max(S.V) max(S.lp) sum(S.lp > 100) S.loss];
        fprintf('%-22s %-12s  %d   %5.3f  %5.3f  %7.0f %%  %6d   %7.0f\n', steplog{k,1}, steplog{k,2}, 1, T(k,:));
    else
        T(k,:) = nan;
        fprintf('%-22s %-12s  0   (해 없음 - 전압붕괴)\n', steplog{k,1}, steplog{k,2});
    end
end
fid = fopen(fullfile(outdir, 'task1_6_steps.csv'), 'w');
fprintf(fid, 'step,scenario,converged,Vmin,Vmax,max_loading_pct,overloaded_lines,loss_MW\n');
for k = 1:size(steplog, 1)
    fprintf(fid, '%s,%s,%d,%.4f,%.4f,%.1f,%d,%.1f\n', steplog{k,1}, steplog{k,2}, steplog{k,3}.conv, T(k,:));
end
fclose(fid);

fig = figure('visible', 'off', 'position', [0 0 1250 420]);
steps = unique(steplog(:,1), 'stable');  ns = numel(steps);
for s = 1:2
    rows = find(strcmp(steplog(:,2), sc_kr{s}));
    subplot(1, 3, 1); hold on;  plot(1:ns, T(rows,3), 'o-', 'linewidth', 2);
    subplot(1, 3, 2); hold on;  plot(1:ns, T(rows,1), 'o-', 'linewidth', 2);
    subplot(1, 3, 3); hold on;  plot(1:ns, T(rows,5), 'o-', 'linewidth', 2);
end
lbl = {'대책없음', 'HVDC', '+선로증설', '+STATCOM'};  lbl = lbl(1:ns);
subplot(1,3,1); plot([1 ns], [100 100], 'r--'); title('최대 선로 부하율 [%]'); grid on; box on;
text(1.05, 105, {'경부하: 해 없음', '(전압붕괴)'}, 'fontsize', 9, 'color', [0.85 0.33 0.1]);
set(gca, 'xtick', 1:ns, 'xticklabel', lbl); legend(sc_kr, 'location', 'northeast');
subplot(1,3,2); plot([1 ns], [0.95 0.95], 'r--'); title('최저 전압 [pu]'); grid on; box on;
set(gca, 'xtick', 1:ns, 'xticklabel', lbl); ylim([0.85 1.05]);
subplot(1,3,3); title('송전손실 [MW]'); grid on; box on; set(gca, 'xtick', 1:ns, 'xticklabel', lbl);
print(fig, '-dpng', '-r110', fullfile(outdir, 'task1_6_steps.png')); close(fig);

save(fullfile(outdir, 'task1_6_result.mat'), 'M', 'hv_def', 'final', 'steplog');
