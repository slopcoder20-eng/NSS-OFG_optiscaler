import torch
import torch.nn.functional as F

x = torch.arange(48, dtype=torch.float32).view(1, 48, 1, 1)
y = F.pixel_shuffle(x, 4)
print('y shape:', y.shape)
for c in range(3):
    print(f'c={c}:')
    print(y[0, c].numpy())

