%% Task 1-3 : 9모선 미래 계통 안정도(전압·과부하) 문제 해소방안
%   기본 해석(Task 1-2) 결과 문제점
%     - 9-3 (충남→서울) 선로 부하율 206 %   : 서울 부하 60 GW 가 단일 경로로 공급
%     - 9-6 (전남→충남) 선로 부하율 137 %   : 전남 재생E 60 GW 가 북상
%     - 서울(0.922), 경기(0.946), 충남(0.943) 저전압
%   대안별로 조류계산을 반복해서 효과를 비교
clear; clc;
root = fileparts(mfilename('fullpath'));
addpath(fullfile(root, 'lib'));
outdir = fullfile(root, 'results');
c0 = load_9bus(fullfile(root, 'data'));
Sb = c0.baseMVA / 1000;   % 30 GVA

sc = {};   % {이름, 케이스, 설명}
sc(end+1,:) = {'S0 기본', c0, '조치 없음'};

c = c0; c.type([3 8 9]) = 2; c.V0([3 8 9]) = 1.0;
sc(end+1,:) = {'S1 STATCOM', c, '서울·경기·충남에 STATCOM (1.0 pu 전압제어)'};

c = c0; c.Psp(3) = c.Psp(3) + 0.2; c.Qsp(3) = c.Qsp(3) + 0.02;
sc(end+1,:) = {'S2 수요반응', c, '서울 부하 10 % 감축 (6 GW, 역률 유지)'};

c = add_line(c0, 9, 3, 0, 0.0586, 0);
sc(end+1,:) = {'S3 선로증설', c, '충남-서울 9-3 2회선 증설 (동일 임피던스)'};

c = add_hvdc(c0, 6, 3, 18/30, 0.03);
sc(end+1,:) = {'S4 HVDC', c, '전남→서울 HVDC 18 GW (손실 3 %)'};

c = add_line(c0, 9, 3, 0, 0.0586, 0);
c = add_hvdc(c, 6, 3, 18/30, 0.03, 1.02, 1.00);
sc(end+1,:) = {'S5 종합', c, 'S3 + VSC-HVDC 18 GW (양단 전압제어 1.02/1.00 pu)'};

ns = size(sc, 1);
T = zeros(ns, 6);
fprintf('=== Task 1-3 : 9모선 해소방안 비교 ===\n');
fprintf('%-12s %-44s  Vmin   Vmax   최대부하율  손실[GW]  위반선로수  보상Q[GVar]\n', '시나리오', '내용');
for k = 1:ns
    ck = sc{k,2};
    [r, fl, info] = run_case(ck);
    % 추가로 필요한 무효전력 = PV 로 바꾼 모선의 계산 Q - 원래 지정 Q
    extraQ = sum(abs(r.Q(ck.type == 2 & c0.type ~= 2) - ck.Qsp(ck.type == 2 & c0.type ~= 2))) * Sb;
    T(k,:) = [info.Vmin info.Vmax info.maxload info.loss*Sb sum(info.load_pct > 100) extraQ];
    fprintf('%-12s %-44s %6.3f %6.3f %8.0f %%  %8.2f  %8d  %10.1f\n', sc{k,1}, sc{k,3}, T(k,:));
    sc{k,4} = r;  sc{k,5} = info;
end

% 최종안 상세 결과 (실제 단위)
out = report_9bus(sc{end,2}, sc{end,4}, 'Task 1-3: 9-bus 종합 대책 (S5)', outdir, 'task1_3_9bus_final');

% ---- 시나리오 비교 그림 ----
fig = figure('visible', 'off', 'position', [0 0 1300 420]);
names = cellfun(@(x) x(1:2), sc(:,1)', 'uniformoutput', false);   % 'S0'..'S5'
subplot(1,3,1); hold on; box on;
bar(1:ns, [T(:,1) T(:,2)], 'grouped');
plot([0.5 ns+0.5], [0.95 0.95], 'r--', [0.5 ns+0.5], [1.05 1.05], 'r--', 'linewidth', 1.5);
ylim([0.85 1.1]); set(gca, 'xtick', 1:ns, 'xticklabel', names); legend('V_{min}', 'V_{max}', 'location', 'south');
title('최저/최고 전압 [pu]');
subplot(1,3,2); hold on; box on;
bar(1:ns, T(:,3), 0.6, 'facecolor', [0.9 0.55 0.2]);
plot([0.5 ns+0.5], [100 100], 'r--', 'linewidth', 1.5);
set(gca, 'xtick', 1:ns, 'xticklabel', names); title('최대 선로 부하율 [%]');
subplot(1,3,3); box on;
bar(1:ns, T(:,4), 0.6, 'facecolor', [0.4 0.6 0.4]);
set(gca, 'xtick', 1:ns, 'xticklabel', names); title('총 송전손실 [GW]');
annotation('textbox', [0.05 0.0 0.9 0.06], 'string', strjoin(sc(:,1)', '   |   '), 'edgecolor', 'none', 'horizontalalignment', 'center', 'fontsize', 9);
print(fig, '-dpng', '-r110', fullfile(outdir, 'task1_3_compare.png')); close(fig);

fid = fopen(fullfile(outdir, 'task1_3_compare.csv'), 'w');
fprintf(fid, 'scenario,description,Vmin_pu,Vmax_pu,max_loading_pct,loss_GW,overloaded_lines,extra_Q_GVar\n');
for k = 1:ns
    fprintf(fid, '%s,%s,%.4f,%.4f,%.1f,%.3f,%d,%.2f\n', sc{k,1}, sc{k,3}, T(k,:));
end
fclose(fid);
