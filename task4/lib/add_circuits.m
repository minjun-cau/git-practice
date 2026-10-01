function cc = add_circuits(cc, add)
% ADD_CIRCUITS  등가 선로(n회선 묶음)에 회선을 add 개 추가
%   같은 회선 n 개가 병렬 → 1회선 임피던스 z1 = n*z,  (n+a) 회선이면 z' = z * n/(n+a)
%   충전 서셉턴스와 정격용량은 회선 수에 비례 → b' = b*(n+a)/n, rate' = rate*(n+a)/n
    m = (cc.ncir + add(:)) ./ cc.ncir;
    cc.r = cc.r ./ m;  cc.x = cc.x ./ m;
    cc.b = cc.b .* m;  cc.rate = cc.rate .* m;
end
