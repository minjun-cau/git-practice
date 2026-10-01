function c = add_line(c, f, t, r, x, b, rate)
% ADD_LINE  케이스에 선로(회선) 추가 - 선로 신설/증설 시나리오용
    if nargin < 7, rate = 1; end
    c.f(end+1,1) = f;  c.t(end+1,1) = t;
    c.r(end+1,1) = r;  c.x(end+1,1) = x;  c.b(end+1,1) = b;
    c.rate(end+1,1) = rate;
end
