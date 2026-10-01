function list_add(c0, add)
% LIST_ADD  증설한 선로 목록 출력
    for k = find(add(:)' > 0)
        fprintf('   %-8s - %-8s (%3d kV, 기존 %d회선 → +%d)\n', c0.name_kr{c0.f(k)}, c0.name_kr{c0.t(k)}, ...
            c0.br_kv(k), c0.ncir(k), add(k));
    end
end
