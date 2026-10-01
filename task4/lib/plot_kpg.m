function plot_kpg(c, res, lp, title_str, fname)
% PLOT_KPG  194모선 지도(GPS) 위에 전압·선로부하율 표시 + 전압/부하율 분포
    fig = figure('visible', 'off', 'position', [0 0 1400 760]);

    % ---- 지도 ----
    ax1 = axes('position', [0.05 0.08 0.48 0.82]); hold on; box on;
    ord = [find(lp <= 80); find(lp > 80 & lp <= 100); find(lp > 100)];   % 과부하 선로를 위에 그림
    for k = ord'
        x = [c.lon(c.f(k)) c.lon(c.t(k))];  y = [c.lat(c.f(k)) c.lat(c.t(k))];
        if lp(k) > 100,    col = [0.85 0.1 0.1]; lw = 3.5;
        elseif lp(k) > 80, col = [0.95 0.6 0.1]; lw = 2.5;
        else,              col = [0.65 0.7 0.8]; lw = 0.4 + 0.5*(c.br_kv(k) >= 345) + 1.0*(c.br_kv(k) >= 765);
        end
        plot(x, y, '-', 'color', col, 'linewidth', lw);
    end
    sz = 18 + 30 * (c.type == 2) + 60 * (c.type == 1);
    scatter(c.lon, c.lat, sz, res.V, 'filled', 'markeredgecolor', [0.2 0.2 0.2]);
    colormap(ax1, jet(64));  caxis([0.93 1.07]);
    cb = colorbar; set(cb, 'position', [0.545 0.15 0.012 0.65]); ylabel(cb, '|V| [pu]');
    hi = find(res.V > 1.05 | res.V < 0.95);
    for k = hi'
        text(c.lon(k) + 0.04, c.lat(k), sprintf('%s %.3f', c.name_kr{k}, res.V(k)), 'fontsize', 7);
    end
    xlim([125.9 129.6]); ylim([34.2 38.4]);
    xlabel('경도'); ylabel('위도');
    title({title_str, '선로: 회색 ≤80 %, 주황 80~100 %, 빨강 >100 %  / 큰 점 = 발전(PV) 모선'}, 'fontsize', 10);

    % ---- 지역별 전압 범위 (가로 막대: 최저~최고) ----
    axes('position', [0.68 0.56 0.30 0.36]); hold on; box on;
    na = max(c.area);
    for a = 1:na
        v = res.V(c.area == a);
        plot([min(v) max(v)], [a a], '-', 'color', [0.3 0.5 0.8], 'linewidth', 5);
        plot(mean(v), a, 'k.', 'markersize', 10);
    end
    plot([0.95 0.95], [0 na+1], 'r--', [1.05 1.05], [0 na+1], 'r--', 'linewidth', 1.2);
    set(gca, 'ytick', 1:na, 'yticklabel', c.area_name, 'ydir', 'reverse', 'fontsize', 8);
    xlim([0.93 1.08]); ylim([0.5 na+0.5]); xlabel('|V| [pu]'); title('지역별 전압 범위 (점 = 평균)');

    % ---- 선로 부하율 상위 ----
    axes('position', [0.72 0.08 0.26 0.38]); hold on; box on;
    [s, ix] = sort(lp, 'descend');  n = 12;
    barh(1:n, s(n:-1:1), 0.6, 'facecolor', [0.9 0.55 0.2]);
    lbl = arrayfun(@(k) sprintf('%s-%s', c.name_kr{c.f(k)}, c.name_kr{c.t(k)}), ix(n:-1:1), 'uniformoutput', false);
    set(gca, 'ytick', 1:n, 'yticklabel', lbl, 'fontsize', 7);
    plot([100 100], [0.5 n+0.5], 'r--', 'linewidth', 1.5);
    xlabel('부하율 [%]'); title('선로 부하율 상위 12');
    xlim([0 max(120, s(1)*1.05)]);

    print(fig, '-dpng', '-r100', fname);
    close(fig);
end
