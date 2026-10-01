%% 자소서 해석 : 194모선 계통에 용인 데이터센터 4 GW 적용
%   - 교류 뉴턴-랩슨 조류해석 (lib/nr_pf.m)
%   - 기준 : 무효전력 한계 미적용, 늘어난 수요는 기준 모선(52 사천)이 공급
%   - 증설 : 회선 수 n 인 등가 선로에 1회선 추가 → r,x ×n/(n+1), b·정격 ×(n+1)/n
%   - HVDC : 강릉(1) 4,000 MW → 서용인(23) 3,880 MW (변환손실 3 %), 부하로 단순화
clear; clc;
root = fileparts(mfilename('fullpath'));
addpath(fullfile(root, 'lib'));
outdir = fullfile(root, 'results');
c0 = load_kpg(fullfile(root, 'data'));

base = js_case(c0, struct('dc', false, 'hvdc', false));
dc   = js_case(c0, struct('dc', true,  'hvdc', false));
hv   = js_case(c0, struct('dc', true,  'hvdc', true));

%% 1) 기본 부하 / 데이터센터 / HVDC 병행
fprintf('=== 자소서 해석 : 용인 데이터센터 4 GW ===\n');
names = {'기본 부하', '용인 데이터센터 4 GW', 'DC + HVDC(강릉→서용인 4 GW)'};
cases = {base, dc, hv};
R = cell(1, 3);
for k = 1:3
    [res, cc, R{k}] = js_solve(cases{k});
    [s, ix] = sort(R{k}.lp, 'descend');
    fprintf('\n[%s] 과부하 %d개, 최대 %.1f %% (%s–%s), 손실 %.0f MW, 전압 %.3f~%.3f pu\n', names{k}, ...
        R{k}.nover, s(1), cc.name_kr{cc.f(ix(1))}, cc.name_kr{cc.t(ix(1))}, R{k}.loss, min(res.V), max(res.V));
    for j = ix(1:R{k}.nover)'
        fprintf('     %-8s – %-8s (%3d kV) %6.1f %%\n', cc.name_kr{cc.f(j)}, cc.name_kr{cc.t(j)}, cc.br_kv(j), R{k}.lp(j));
    end
end
summarize_kpg(dc, js_solve(dc), '자소서: 용인 데이터센터 4 GW', outdir, 'jasoseo_dc');
summarize_kpg(hv, js_solve(hv), '자소서: 데이터센터 + HVDC 강릉→서용인', outdir, 'jasoseo_hvdc');

% 데이터센터로 새로 생긴 과부하 vs 원래 있던 과부하
new_over = find(R{2}.lp > 100 & R{1}.lp <= 100);
fprintf('\n데이터센터 때문에 새로 생긴 과부하 %d개 : ', numel(new_over));
fprintf('%s–%s  ', dc.name_kr{[dc.f(new_over) dc.t(new_over)]'});
fprintf('\nHVDC 병행 후 남은 과부하 %d개는 모두 기본 부하 때부터 있던 선로인가? %d\n', R{3}.nover, ...
    all(R{1}.lp(R{3}.lp > 100) > 100));

%% 2) 증설 회선 수
add_dc = js_greedy(dc);  add_hv = js_greedy(hv);
fprintf('\n=== 과부하 해소 증설 ===\n증설만 : %d회선\n', sum(add_dc));  list_add(c0, add_dc);
fprintf('HVDC 병행 : %d회선\n', sum(add_hv));  list_add(c0, add_hv);

%% 3) 손실
fprintf('\n손실 : 데이터센터 %.0f MW → HVDC 병행 AC 손실 %.0f MW + 변환손실 120 MW = %.0f MW (%.1f %% 감소)\n', ...
    R{2}.loss, R{3}.loss, R{3}.loss + 120, (1 - (R{3}.loss + 120) / R{2}.loss) * 100);

%% 4) 경부하 (부하·발전 0.6배) 과전압 + STATCOM
lt = js_case(c0, struct('dc', false, 'hvdc', false, 'scale', 0.6));
[rl, ccl] = js_solve(lt);
[vmax, ib] = max(rl.V);
[vmn, vmx] = vlim(ccl.kv);
fprintf('\n경부하 : 최고 전압 %.3f pu (%d번 %s, %d kV), 허용범위 초과 %d개\n', vmax, ib, ccl.name_kr{ib}, ccl.kv(ib), sum(rl.V > vmx));
ls = js_case(c0, struct('dc', false, 'hvdc', false, 'scale', 0.6, 'statcom', [74 1.03]));
[rs, ccs] = js_solve(ls);
Qst = (rs.Q(74) + ccs.Qd(74) / 100) * 100;
fprintf('74번 STATCOM 1.03 pu 제어 : 무효전력 %.0f Mvar (음수 = 흡수), 최고 전압 %.3f, 허용범위 초과 %d개\n', ...
    Qst, max(rs.V), sum(rs.V > vmx));

%% 5) 가정을 바꿔도 결론이 유지되는가
fprintf('\n=== 민감도 ===\n');
fprintf('%-40s 증설만  HVDC 병행\n', '');
fprintf('%-40s %4d    %4d\n', '기준 (기준 모선 공급, Q 한계 없음)', sum(add_dc), sum(add_hv));
dcA = js_case(c0, struct('dc', true, 'hvdc', false, 'share', 'all'));
hvA = js_case(c0, struct('dc', true, 'hvdc', true,  'share', 'all'));
sA = [sum(js_greedy(dcA)) sum(js_greedy(hvA))];
fprintf('%-40s %4d    %4d\n', '증가분을 모든 발전기가 출력 비례 분담', sA);
sQ = [sum(js_greedy(dc, true)) sum(js_greedy(hv, true))];
fprintf('%-40s %4d    %4d\n', '발전기 무효전력 한계 적용', sQ);

%% 6) 요약 그림
fig = figure('visible', 'off', 'position', [0 0 1150 420]);
subplot(1, 2, 1);
bar([R{1}.nover R{2}.nover R{3}.nover], 0.6, 'facecolor', [0.85 0.35 0.2]);
set(gca, 'xticklabel', {'기본 부하', '+데이터센터 4 GW', '+HVDC 병행'});
ylabel('과부하 선로 수'); title('100 % 초과 선로'); grid on;
for k = 1:3, text(k, R{k}.nover + 0.25, sprintf('%d개', R{k}.nover), 'horizontalalignment', 'center'); end
ylim([0 9]);
subplot(1, 2, 2);
Y = [sum(add_dc) sum(add_hv); sA; sQ];
bar(Y, 'grouped');
set(gca, 'xticklabel', {'기준', '모든 발전기 분담', 'Q 한계 적용'});
legend('증설만', 'HVDC 병행', 'location', 'northwest');
ylabel('필요 증설 회선 수'); title('과부하 해소에 필요한 증설'); grid on;
print(fig, '-dpng', '-r110', fullfile(outdir, 'jasoseo_summary.png')); close(fig);
