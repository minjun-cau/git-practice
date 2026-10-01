function plot_9bus(c, res, load_pct, fl, title_str, fname)
% PLOT_9BUS  (좌) 지역 계통도 + 전압/조류  (우상) 모선 전압  (우하) 선로 부하율
    Sb = c.baseMVA / 1000;
    fig = figure('visible', 'off', 'position', [0 0 1300 650]);

    % --- 계통도 ---
    subplot(2, 2, [1 3]); hold on; box on;
    for k = 1:numel(c.f)
        p1 = c.xy(c.f(k), :); p2 = c.xy(c.t(k), :);
        lw = 1 + 6 * min(load_pct(k), 120) / 100;
        col = [0.2 0.4 0.8];
        if load_pct(k) > 80, col = [0.95 0.6 0.1]; end
        if load_pct(k) > 100, col = [0.85 0.1 0.1]; end
        plot([p1(1) p2(1)], [p1(2) p2(2)], '-', 'color', col, 'linewidth', lw);
        P = real(fl.Sij(k)) * Sb;
        m = (p1 + p2) / 2;
        text(m(1), m(2), {sprintf('%.1f GW', abs(P)), sprintf('%.0f%%', load_pct(k))}, 'fontsize', 8, ...
             'horizontalalignment', 'center', 'color', [0.15 0.15 0.15]);
    end
    for k = 1:c.nb
        if res.V(k) < 0.95, fc = [0.85 0.1 0.1];
        elseif res.V(k) > 1.05, fc = [0.6 0.1 0.8];
        else, fc = [0.1 0.6 0.2]; end
        mk = 'o'; if c.type(k) == 1, mk = 's'; elseif c.type(k) == 2, mk = 'd'; end
        plot(c.xy(k,1), c.xy(k,2), mk, 'markersize', 14, 'markerfacecolor', fc, 'markeredgecolor', 'k');
        text(c.xy(k,1) + 0.12, c.xy(k,2) + 0.12, {sprintf('%d %s', k, c.name_kr{k}), sprintf('%.3f pu', res.V(k))}, ...
             'fontsize', 8, 'fontweight', 'bold');
    end
    xlim([126.2 129.6]); ylim([34.6 38.2]); set(gca, 'xtick', [], 'ytick', []);
    title({title_str, '■ Slack  ◆ PV  ● PQ  (빨강: 저전압, 보라: 과전압)'}, 'fontsize', 10);

    % --- 전압 ---
    subplot(2, 2, 2); hold on; box on;
    bar(1:c.nb, res.V, 0.6, 'facecolor', [0.3 0.5 0.8]);
    plot([0.5 c.nb+0.5], [0.95 0.95], 'r--', 'linewidth', 1.5);
    plot([0.5 c.nb+0.5], [1.05 1.05], 'r--', 'linewidth', 1.5);
    ylim([0.85 1.10]); xlim([0.5 c.nb+0.5]);
    set(gca, 'xtick', 1:c.nb, 'xticklabel', c.name_kr, 'fontsize', 8);
    ylabel('|V| [pu]'); title('모선 전압 (허용범위 0.95~1.05 pu)');

    % --- 선로 부하율 ---
    subplot(2, 2, 4); hold on; box on;
    nl = numel(c.f);
    bar(1:nl, load_pct, 0.6, 'facecolor', [0.9 0.55 0.2]);
    plot([0.5 nl+0.5], [100 100], 'r--', 'linewidth', 1.5);
    lbl = arrayfun(@(k) sprintf('%d-%d', c.f(k), c.t(k)), 1:nl, 'uniformoutput', false);
    set(gca, 'xtick', 1:nl, 'xticklabel', lbl, 'fontsize', 8);
    xlim([0.5 nl+0.5]); ylim([0 max(120, max(load_pct)*1.1)]);
    ylabel('부하율 [%] (1 pu = 30 GW)'); title('선로 부하율');

    print(fig, '-dpng', '-r110', fname);
    close(fig);
end
