function Ybus = make_ybus(nb, fbus, tbus, r, x, b)
% MAKE_YBUS  모선 어드미턴스 행렬 구성 (Bergen Ch.9)
%   nb   : 모선 수
%   fbus, tbus : 선로 양 끝 모선 번호
%   r, x : 직렬 임피던스 [pu]
%   b    : 선로 전체 충전 서셉턴스 [pu]  -> 양 끝에 b/2 씩 연결 (pi 등가회로)
%
%   y = 1/(r + jx)
%   Y(i,i) += y + jb/2,  Y(j,j) += y + jb/2,  Y(i,j) = Y(j,i) -= y

    y   = 1 ./ (r(:) + 1j*x(:));
    ysh = 1j * b(:) / 2;
    f = fbus(:); t = tbus(:);

    % sparse() 는 같은 위치의 값을 자동으로 더해줌 (병렬 회선 처리)
    Ybus = sparse([f; t; f; t], [f; t; t; f], ...
                  [y + ysh; y + ysh; -y; -y], nb, nb);
end
